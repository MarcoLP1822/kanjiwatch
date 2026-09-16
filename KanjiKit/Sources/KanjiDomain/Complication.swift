import Foundation

extension Kanji {
    /// I primi due significati: è quanto ci sta su un quadrante. Lo usano notifica,
    /// letture e complication, quindi sta scritto qui una volta sola.
    public var shortMeaning: String { firstTwo(meanings) }
}

extension Kanji.Word {
    public var shortMeaning: String { firstTwo(meanings) }
}

private func firstTwo(_ meanings: [String]) -> String {
    meanings.prefix(2).joined(separator: ", ")
}

/// Quello che serve alla complication in un istante preciso.
///
/// Contiene già carattere, significato e tratti: l'estensione della complication
/// ha pochi MB di memoria e pochi millisecondi, e non deve caricare un mazzo da
/// duemila kanji per disegnarne uno.
public struct GlanceEntry: Equatable, Sendable, Codable {
    public let date: Date
    public let codepoint: String
    public let character: String
    public let meaning: String
    public let strokes: [String]

    public init(date: Date, kanji: Kanji) {
        self.date = date
        self.codepoint = kanji.codepoint
        self.character = kanji.character
        self.meaning = kanji.shortMeaning
        self.strokes = kanji.strokes
    }
}

/// La sequenza di kanji da mostrare sul quadrante.
public enum ComplicationTimeline {
    /// Adesso il kanji in gioco, poi uno per ogni notifica in coda, ciascuno dal
    /// momento in cui arriva la sua notifica: quadrante, app e notifica dicono sempre
    /// la stessa cosa.
    public static func entries(
        now: Date,
        current: Kanji,
        upcoming: [ScheduledReminder],
        deck: KanjiDeck
    ) -> [GlanceEntry] {
        let queued =
            upcoming
            .filter { $0.fireDate > now }
            .sorted { $0.fireDate < $1.fireDate }
            // Un kanji uscito dal mazzo dopo la programmazione si salta.
            .compactMap { reminder in deck[reminder.codepoint].map { GlanceEntry(date: reminder.fireDate, kanji: $0) } }
        return [GlanceEntry(date: now, kanji: current)] + queued
    }
}
