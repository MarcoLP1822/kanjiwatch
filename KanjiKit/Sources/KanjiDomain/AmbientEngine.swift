import Foundation

/// Un incontro deciso dal motore: quando, quale kanji, e che tipo di contatto è.
public struct AmbientSelection: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        /// Un kanji mai visto.
        case new
        /// Uno che sta incontrando: `fresh` o `reinforcing`.
        case learning
        /// Uno che gli è già passato davanti parecchie volte.
        case familiar
    }

    public let fireDate: Date
    public let codepoint: String
    public let kind: Kind

    public init(fireDate: Date, codepoint: String, kind: Kind) {
        self.fireDate = fireDate
        self.codepoint = codepoint
        self.kind = kind
    }
}

/// Decide cosa ti passa davanti durante la giornata.
///
/// Non sceglie un kanji al momento della notifica: watchOS ne tiene in coda fino a
/// 64 quando l'app non gira, quindi il motore **simula** le esposizioni future su
/// una copia dello storico. Quella copia non si salva: un'esposizione conta solo
/// quando il suo momento arriva davvero.
///
/// Tutto è deterministico — niente caso, niente mescolamenti. Rischedulare due
/// volte senza che sia successo niente dà la stessa coda; se invece l'utente ha
/// aperto qualcosa, la coda cambia, ed è esattamente quello che vogliamo.
public enum AmbientEngine {
    /// Cinque rinforzi, tre nuovi, due familiari ogni dieci contatti. È un pattern e
    /// non una probabilità perché il caso, su dieci estrazioni, ti regala giornate
    /// da sei kanji nuovi — l'opposto di quello che deve fare questa app.
    public static let rhythm: [AmbientSelection.Kind] = [
        .learning, .new, .learning, .familiar, .learning, .new, .learning, .familiar, .learning, .new,
    ]

    /// Il tetto ai kanji nuovi del giorno. Alzare la frequenza deve aumentare le
    /// esposizioni, non la roba da imparare: con trenta contatti al giorno restano
    /// cinque volti nuovi e venticinque incontri con quelli di prima.
    public static let defaultNewPerDay = 5

    public static func plan(
        fireDates: [Date],
        deck: KanjiDeck,
        state: AmbientState,
        currentCodepoint: String? = nil,
        newPerDay: Int = defaultNewPerDay,
        calendar: Calendar = .current
    ) -> [AmbientSelection] {
        guard !deck.isEmpty else { return [] }

        var projected = state
        // Il kanji in gioco conta come "appena visto": la prima notifica della coda
        // non deve ripetere quello che hai davanti adesso.
        var recent = [currentCodepoint].compactMap { $0 }
        var introduced: [Date: Int] = [:]
        var selections: [AmbientSelection] = []

        for (position, fireDate) in fireDates.enumerated() {
            let day = calendar.startOfDay(for: fireDate)
            // I kanji nuovi già introdotti quel giorno, anche da un piano precedente:
            // rischedulare a metà pomeriggio non riapre il budget della giornata.
            let already =
                introduced[day]
                ?? projected.records.values.count { calendar.isDate($0.firstSeenAt, inSameDayAs: fireDate) }
            introduced[day] = already

            guard
                let choice = choose(
                    rhythm[position % rhythm.count],
                    deck: deck,
                    state: projected,
                    at: fireDate,
                    recent: recent,
                    allowsNew: already < newPerDay
                )
            else { continue }

            selections.append(AmbientSelection(fireDate: fireDate, codepoint: choice.codepoint, kind: choice.kind))
            if choice.kind == .new { introduced[day] = already + 1 }
            projected.record(.presented, codepoint: choice.codepoint, at: fireDate)
            recent.append(choice.codepoint)
            if recent.count > 2 { recent.removeFirst() }
        }
        return selections
    }

    /// Cosa mostrare adesso: un solo contatto, con le stesse regole della coda.
    public static func pick(
        at date: Date,
        deck: KanjiDeck,
        state: AmbientState,
        after onScreen: String? = nil,
        newPerDay: Int = defaultNewPerDay,
        calendar: Calendar = .current
    ) -> AmbientSelection? {
        plan(
            fireDates: [date],
            deck: deck,
            state: state,
            currentCodepoint: onScreen,
            newPerDay: newPerDay,
            calendar: calendar
        ).first
    }

    /// Il tipo di contatto è un desiderio, non un obbligo: il primo giorno non c'è
    /// niente da rinforzare, e a budget esaurito non si introduce niente di nuovo.
    private static func choose(
        _ wanted: AmbientSelection.Kind,
        deck: KanjiDeck,
        state: AmbientState,
        at date: Date,
        recent: [String],
        allowsNew: Bool
    ) -> (codepoint: String, kind: AmbientSelection.Kind)? {
        let order: [AmbientSelection.Kind] =
            switch wanted {
            case .new: [.new, .learning, .familiar]
            case .learning: [.learning, .new, .familiar]
            case .familiar: [.familiar, .learning, .new]
            }

        // Mai lo stesso kanji due volte di fila, e quando si può nemmeno a distanza di
        // due. La distanza di due però cede prima del tipo di contatto: il primo
        // giorno, con due soli kanji visti, alternarli è meglio che introdurne un
        // terzo solo per non ripetersi.
        let allowed = order.filter { $0 != .new || allowsNew }
        for kind in allowed {
            for excluded in [Set(recent.suffix(2)), Set(recent.suffix(1))] {
                if let codepoint = best(kind, deck: deck, state: state, at: date, excluding: excluded) {
                    return (codepoint, kind)
                }
            }
        }
        // Un mazzo da un kanji solo: ripeterlo è meglio che non mostrare niente.
        return allowed.lazy
            .compactMap { kind in
                best(kind, deck: deck, state: state, at: date, excluding: []).map { ($0, kind) }
            }
            .first
    }

    private static func best(
        _ kind: AmbientSelection.Kind,
        deck: KanjiDeck,
        state: AmbientState,
        at date: Date,
        excluding: Set<String>
    ) -> String? {
        switch kind {
        case .new:
            // Ordine stabile e con un senso: prima le classi basse, poi i più comuni
            // sui giornali. Il codepoint decide solo i pari merito.
            return
                deck.kanji.lazy
                .filter { state.records[$0.codepoint] == nil && !excluding.contains($0.codepoint) }
                .min {
                    ($0.grade ?? .max, $0.frequencyRank ?? .max, $0.codepoint)
                        < ($1.grade ?? .max, $1.frequencyRank ?? .max, $1.codepoint)
                }?
                .codepoint

        case .learning, .familiar:
            let stages: Set<FamiliarityStage> = kind == .familiar ? [.familiar] : [.fresh, .reinforcing]
            // Vince chi è più in ritardo. `nextDueAt` non è una scadenza da aspettare:
            // il primo giorno tutti sono in anticipo, e il kanji introdotto alle 8
            // torna lo stesso alle 10.
            return
                deck.kanji.lazy
                .compactMap { kanji in state.records[kanji.codepoint].map { (kanji, $0) } }
                .filter { stages.contains($0.1.stage(at: date)) && !excluding.contains($0.0.codepoint) }
                .min {
                    ($0.1.nextDueAt, $0.1.lastPresentedAt, $0.0.frequencyRank ?? .max, $0.0.codepoint)
                        < ($1.1.nextDueAt, $1.1.lastPresentedAt, $1.0.frequencyRank ?? .max, $1.0.codepoint)
                }?
                .0.codepoint
        }
    }
}
