import Foundation

/// Le regole del loop, sullo stato salvato e senza porte: si provano senza orologi
/// né notifiche.
///
///     kanji → tratti → letture ─┬─ DONE: si aspetta la prossima notifica
///                               └─ NEXT: la prossima notifica, anticipata a adesso
extension ReminderState {
    public enum NextOutcome: Equatable, Sendable {
        case showing(String)
        /// La giornata ha già avuto i suoi kanji.
        case dailyLimitReached
        case emptyDeck
    }

    /// Il passo comune a ogni lettura dello stato, dell'app e dello scheduler.
    mutating func catchUp(
        with deck: KanjiDeck,
        now: Date,
        using generator: inout some RandomNumberGenerator,
        calendar: Calendar
    ) {
        // Un aggiornamento dell'app o un grado spento possono aver cambiato il mazzo.
        cycle.reconcile(with: deck.codepoints, using: &generator)
        recordDeliveries(now: now, calendar: calendar)
        // Senza, un kanji uscito dal mazzo resterebbe in coda per sempre: a ogni
        // rischedulazione tornerebbe in testa e verrebbe scartato di nuovo.
        scheduled.removeAll { deck[$0.codepoint] == nil }
    }

    /// Le notifiche arrivate dall'ultima volta contano nella loro giornata, e la più
    /// recente prende il posto del kanji in gioco se è arrivata dopo di lui.
    public mutating func recordDeliveries(now: Date, calendar: Calendar) {
        let delivered = scheduled.filter { $0.fireDate <= now }
        guard !delivered.isEmpty else { return }
        scheduled.removeAll { $0.fireDate <= now }
        today.add(delivered.count { calendar.isDate($0.fireDate, inSameDayAs: now) }, on: now, calendar: calendar)

        if let latest = delivered.max(by: { $0.fireDate < $1.fireDate }),
            latest.fireDate > (session.since ?? .distantPast)
        {
            session = StudySession(codepoint: latest.codepoint, isDone: false, since: latest.fireDate)
        }
    }

    /// NEXT premuto guardando `onScreen`. Non inventa un kanji in più: prende quello
    /// della prossima notifica e lo anticipa, quindi conta nella giornata e fa
    /// ripartire l'intervallo da adesso. `dailyLimit` nil vale solo per il primissimo
    /// kanji, che non può essere negato.
    public mutating func advance(
        after onScreen: String?,
        now: Date,
        dailyLimit: Int?,
        using generator: inout some RandomNumberGenerator,
        calendar: Calendar
    ) -> NextOutcome {
        recordDeliveries(now: now, calendar: calendar)
        // Mentre studiavi è arrivata una notifica: il prossimo è il suo kanji, già contato.
        if let arrived = session.codepoint, arrived != onScreen {
            return .showing(arrived)
        }
        if let dailyLimit, today.count(on: now, calendar: calendar) >= dailyLimit {
            return .dailyLimitReached
        }

        let codepoint: String
        if let upcoming = scheduled.min(by: { $0.fireDate < $1.fireDate }) {
            codepoint = upcoming.codepoint
            scheduled.removeAll { $0 == upcoming }
        } else if let drawn = cycle.next(using: &generator) {
            codepoint = drawn
        } else {
            return .emptyDeck
        }

        today.add(1, on: now, calendar: calendar)
        session = StudySession(codepoint: codepoint, isDone: false, since: now)
        // Al minuto, come i trigger delle notifiche: con i secondi l'app crederebbe
        // arrivata alle 10:12:37 una notifica che il sistema consegna alle 10:12:00.
        anchor = calendar.dateInterval(of: .minute, for: now)?.start ?? now
        return .showing(codepoint)
    }

    /// DONE sul kanji che hai davanti. Se nel frattempo ne è arrivato un altro,
    /// quello non l'hai ancora visto: non è fatto.
    public mutating func markDone(_ onScreen: String) {
        guard session.codepoint == onScreen else { return }
        session.isDone = true
    }

    /// Una notifica toccata: il suo kanji entra in gioco, da capo. L'arrivo l'ha già
    /// contato `recordDeliveries`.
    public mutating func open(codepoint: String, now: Date) {
        session = StudySession(codepoint: codepoint, isDone: false, since: now)
    }
}

/// Il loop con le sue porte: legge e salva lo stato, e dice alla UI cosa mostrare.
public struct StudyLoop {
    /// Quello che la schermata deve sapere, già risolto.
    public struct Snapshot: Equatable, Sendable {
        public let current: Kanji
        /// Quando il kanji è entrato in gioco: distingue due turni anche quando il
        /// carattere si ripete.
        public let startedAt: Date?
        public let isDone: Bool
        /// La prossima notifica in coda. Nil se non ne arriverà nessuna.
        public let nextArrival: Date?
        public let dailyLimitReached: Bool
    }

    public let deck: KanjiDeck
    private let settings: any ValueStore<ReminderSettings>
    private let state: any ValueStore<ReminderState>
    private let now: () -> Date
    private let calendar: Calendar

    public init(
        deck: KanjiDeck,
        settings: any ValueStore<ReminderSettings>,
        state: any ValueStore<ReminderState>,
        now: @escaping () -> Date = Date.init,
        calendar: Calendar = .current
    ) {
        self.deck = deck
        self.settings = settings
        self.state = state
        self.now = now
        self.calendar = calendar
    }

    /// Cosa mostrare adesso. Al primissimo avvio, o se il kanji in gioco è uscito
    /// dal mazzo, se ne prende uno nuovo come con NEXT.
    public func current() -> Snapshot? {
        update { value, moment, generator in
            guard value.session.codepoint.flatMap({ deck[$0] }) == nil else { return }
            _ = value.advance(
                after: value.session.codepoint, now: moment, dailyLimit: nil, using: &generator, calendar: calendar)
        }
    }

    public func next(after onScreen: String) -> Snapshot? {
        update { value, moment, generator in
            _ = value.advance(
                after: onScreen, now: moment, dailyLimit: settings.load().dailyLimit, using: &generator,
                calendar: calendar)
        }
    }

    public func done(_ onScreen: String) -> Snapshot? {
        update { value, _, _ in value.markDone(onScreen) }
    }

    public func open(codepoint: String) -> Snapshot? {
        update { value, moment, _ in
            guard deck[codepoint] != nil else { return }
            value.open(codepoint: codepoint, now: moment)
        }
    }

    /// Carica, recupera, applica il gesto e salva: tutti i gesti passano di qui, così
    /// nessuno dimentica un passo.
    private func update(
        _ change: (inout ReminderState, Date, inout SystemRandomNumberGenerator) -> Void
    ) -> Snapshot? {
        let moment = now()
        var value = state.load()
        var generator = SystemRandomNumberGenerator()
        value.catchUp(with: deck, now: moment, using: &generator, calendar: calendar)
        change(&value, moment, &generator)
        state.save(value)

        guard let codepoint = value.session.codepoint, let kanji = deck[codepoint] else { return nil }
        return Snapshot(
            current: kanji,
            startedAt: value.session.since,
            isDone: value.session.isDone,
            nextArrival: value.scheduled.map(\.fireDate).min(),
            dailyLimitReached: value.today.count(on: moment, calendar: calendar) >= settings.load().dailyLimit
        )
    }
}
