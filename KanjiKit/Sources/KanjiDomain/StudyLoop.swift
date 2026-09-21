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
    ///
    /// Qui le due memorie si incontrano: le notifiche la cui ora è passata diventano
    /// esposizioni. Quelle ancora in coda no — il piano le ha previste, e prevederle
    /// non è averle viste.
    ///
    /// Sappiamo che l'ora è passata, non che l'utente abbia guardato il polso: è
    /// un'approssimazione, ed è consapevole. watchOS non dà nessun evento affidabile
    /// che dica "l'ha vista", e chiederglielo sarebbe la domanda che quest'app non fa.
    /// I segnali veri — `opened`, `readingsViewed` — pesano di più proprio per questo.
    /// Contarle una volta sola invece è garantito: chi è arrivato esce dalla coda.
    mutating func catchUp(
        with deck: KanjiDeck,
        now: Date,
        ambient: inout AmbientState,
        calendar: Calendar
    ) {
        for delivered in recordDeliveries(now: now, calendar: calendar) {
            ambient.record(
                .presented, codepoint: delivered.codepoint, content: delivered.content, at: delivered.fireDate)
        }
        // Senza, un kanji uscito dal mazzo resterebbe in coda per sempre: a ogni
        // rischedulazione tornerebbe in testa e verrebbe scartato di nuovo.
        scheduled.removeAll { deck[$0.codepoint] == nil }
    }

    /// Le notifiche arrivate dall'ultima volta contano nella loro giornata, e la più
    /// recente prende il posto del kanji in gioco se è arrivata dopo di lui.
    ///
    /// Restituisce quelle arrivate, perché chi tiene lo storico delle esposizioni ha
    /// bisogno di sapere quali sono: così la regola di apprendimento non finisce
    /// dentro lo stato delle notifiche.
    @discardableResult
    public mutating func recordDeliveries(now: Date, calendar: Calendar) -> [ScheduledReminder] {
        let delivered = scheduled.filter { $0.fireDate <= now }
        guard !delivered.isEmpty else { return [] }
        scheduled.removeAll { $0.fireDate <= now }
        today.add(delivered.count { calendar.isDate($0.fireDate, inSameDayAs: now) }, on: now, calendar: calendar)

        if let latest = delivered.max(by: { $0.fireDate < $1.fireDate }),
            latest.fireDate > (session.since ?? .distantPast)
        {
            session = StudySession(
                codepoint: latest.codepoint,
                isDone: false,
                since: latest.fireDate,
                content: latest.content,
                reference: latest.reference
            )
        }
        return delivered
    }

    /// NEXT premuto guardando `onScreen`. Non inventa un kanji in più: prende quello
    /// della prossima notifica e lo anticipa, quindi conta nella giornata e fa
    /// ripartire l'intervallo da adesso. `dailyLimit` nil vale solo per il primissimo
    /// kanji, che non può essere negato.
    ///
    /// `draw` è l'Ambient Engine: serve solo quando non c'è nessuna notifica in coda
    /// da anticipare — a permesso negato, o al primissimo avvio.
    public mutating func advance(
        after onScreen: String?,
        now: Date,
        dailyLimit: Int?,
        draw: () -> ReminderDestination?,
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

        let next: ReminderDestination
        if let upcoming = scheduled.min(by: { $0.fireDate < $1.fireDate }) {
            next = upcoming.destination
            // Anticipata vuol dire consumata: lasciarla in coda la farebbe arrivare
            // una seconda volta, contata e mostrata di nuovo.
            scheduled.removeAll { $0 == upcoming }
        } else if let drawn = draw() {
            next = drawn
        } else {
            return .emptyDeck
        }

        let codepoint = next.codepoint
        today.add(1, on: now, calendar: calendar)
        session = StudySession(
            codepoint: codepoint, isDone: false, since: now, content: next.content, reference: next.reference)
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

    /// Una notifica toccata: il suo kanji entra in gioco, da capo, nella forma in cui
    /// l'hai guardato al polso. L'arrivo l'ha già contato `recordDeliveries`.
    public mutating func open(_ destination: ReminderDestination, now: Date) {
        session = StudySession(
            codepoint: destination.codepoint,
            isDone: false,
            since: now,
            content: destination.content,
            reference: destination.reference
        )
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
        /// Quale delle parole del kanji mostrano le letture: quella della notifica
        /// che ha aperto il giro.
        public let reference: ExposureReference
        /// La prossima notifica in coda. Nil se non ne arriverà nessuna.
        public let nextArrival: Date?
        public let dailyLimitReached: Bool
    }

    public let deck: KanjiDeck
    private let settings: any ValueStore<ReminderSettings>
    private let state: any ValueStore<ReminderState>
    private let ambient: any ValueStore<AmbientState>
    /// Una funzione e non un valore: l'abbonamento può cambiare mentre l'app è
    /// aperta, e il loro loop vive quanto la schermata.
    private let mode: () -> AmbientMode
    private let now: () -> Date
    private let calendar: Calendar

    public init(
        deck: KanjiDeck,
        settings: any ValueStore<ReminderSettings>,
        state: any ValueStore<ReminderState>,
        ambient: any ValueStore<AmbientState>,
        mode: @escaping () -> AmbientMode = { .standard },
        now: @escaping () -> Date = Date.init,
        calendar: Calendar = .current
    ) {
        self.deck = deck
        self.settings = settings
        self.state = state
        self.ambient = ambient
        self.mode = mode
        self.now = now
        self.calendar = calendar
    }

    /// Cosa mostrare adesso. Al primissimo avvio, o se il kanji in gioco è uscito
    /// dal mazzo, se ne prende uno nuovo come con NEXT.
    public func current() -> Snapshot? {
        update { value, exposure, moment in
            guard value.session.codepoint.flatMap({ deck[$0] }) == nil else { return }
            advance(&value, &exposure, after: value.session.codepoint, at: moment, dailyLimit: nil)
        }
    }

    public func next(after onScreen: String) -> Snapshot? {
        update { value, exposure, moment in
            advance(&value, &exposure, after: onScreen, at: moment, dailyLimit: settings.load().dailyLimit)
        }
    }

    public func done(_ onScreen: String) -> Snapshot? {
        update { value, _, _ in value.markDone(onScreen) }
    }

    /// Aprire è un segnale più forte di vedere: la notifica l'hai guardata davvero.
    public func open(_ destination: ReminderDestination) -> Snapshot? {
        update { value, exposure, moment in
            guard deck[destination.codepoint] != nil else { return }
            value.open(destination, now: moment)
            exposure.record(.opened, codepoint: destination.codepoint, content: destination.content, at: moment)
        }
    }

    /// Sei arrivato a letture e parola. È il segnale più forte che abbiamo senza
    /// chiederti niente, e allontana il momento in cui quel kanji tornerà.
    public func readingsViewed(_ codepoint: String) {
        let session = state.load().session
        // La forma è quella con cui il kanji è entrato in gioco: se era lì da solo,
        // essere arrivato fin qui vuol dire qualcosa; se il significato c'era già
        // scritto, no.
        let content = session.codepoint == codepoint ? session.content : .introduce
        var exposure = ambient.load()
        exposure.record(.readingsViewed, codepoint: codepoint, content: content, at: now())
        ambient.save(exposure)
    }

    /// Mette in gioco il prossimo kanji e ne segna l'esposizione — ma solo se è
    /// davvero un contatto nuovo: quello arrivato con una notifica l'ha già contato
    /// `catchUp`, all'ora in cui è arrivato.
    private func advance(
        _ value: inout ReminderState,
        _ exposure: inout AmbientState,
        after onScreen: String?,
        at moment: Date,
        dailyLimit: Int?
    ) {
        let arrived = value.session.codepoint
        let outcome = value.advance(
            after: onScreen,
            now: moment,
            dailyLimit: dailyLimit,
            draw: {
                AmbientEngine.pick(
                    at: moment,
                    deck: deck,
                    state: exposure,
                    after: onScreen,
                    newPerDay: settings.load().newKanjiPerDay,
                    mode: mode(),
                    calendar: calendar
                )
                .map { ReminderDestination(codepoint: $0.codepoint, content: $0.content, reference: $0.reference) }
            },
            calendar: calendar
        )
        if case .showing(let codepoint) = outcome, codepoint != arrived {
            exposure.record(.presented, codepoint: codepoint, content: value.session.content, at: moment)
        }
    }

    /// Carica, recupera, applica il gesto e salva: tutti i gesti passano di qui, così
    /// nessuno dimentica un passo.
    private func update(
        _ change: (inout ReminderState, inout AmbientState, Date) -> Void
    ) -> Snapshot? {
        let moment = now()
        var value = state.load()
        var exposure = ambient.load()
        value.catchUp(with: deck, now: moment, ambient: &exposure, calendar: calendar)
        change(&value, &exposure, moment)
        state.save(value)
        ambient.save(exposure)

        guard let codepoint = value.session.codepoint, let kanji = deck[codepoint] else { return nil }
        return Snapshot(
            current: kanji,
            startedAt: value.session.since,
            isDone: value.session.isDone,
            reference: value.session.reference,
            nextArrival: value.scheduled.map(\.fireDate).min(),
            dailyLimitReached: value.today.count(on: moment, calendar: calendar) >= settings.load().dailyLimit
        )
    }
}
