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
    /// In che forma mostrarlo, la stessa della notifica di quel momento: il polso
    /// non deve raccontare due cose diverse nello stesso istante.
    public let content: ExposureContent
    public let character: String
    public let meaning: String
    public let strokes: [String]
    public let word: String?
    public let wordReading: String?
    public let wordMeaning: String?

    public init(date: Date, kanji: Kanji, content: ExposureContent = .introduce) {
        self.date = date
        self.codepoint = kanji.codepoint
        self.content = content.resolved(hasWord: kanji.commonWord != nil)
        self.character = kanji.character
        self.meaning = kanji.shortMeaning
        self.strokes = kanji.strokes
        self.word = kanji.commonWord?.text
        self.wordReading = kanji.commonWord?.reading
        self.wordMeaning = kanji.commonWord?.shortMeaning
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decode(Date.self, forKey: .date)
        codepoint = try container.decode(String.self, forKey: .codepoint)
        character = try container.decode(String.self, forKey: .character)
        meaning = try container.decode(String.self, forKey: .meaning)
        strokes = try container.decode([String].self, forKey: .strokes)
        word = try container.decodeIfPresent(String.self, forKey: .word)
        wordReading = try container.decodeIfPresent(String.self, forKey: .wordReading)
        wordMeaning = try container.decodeIfPresent(String.self, forKey: .wordMeaning)
        // Timeline scritte prima della micro-sequenza: erano tutte "kanji e significato".
        content = (try? container.decodeIfPresent(ExposureContent.self, forKey: .content)) ?? .introduce
    }

    public var destination: ReminderDestination {
        ReminderDestination(codepoint: codepoint, content: content)
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
        currentContent: ExposureContent = .introduce,
        upcoming: [ScheduledReminder],
        deck: KanjiDeck
    ) -> [GlanceEntry] {
        let queued =
            upcoming
            .filter { $0.fireDate > now }
            .sorted { $0.fireDate < $1.fireDate }
            // Un kanji uscito dal mazzo dopo la programmazione si salta.
            .compactMap { reminder in
                deck[reminder.codepoint].map {
                    GlanceEntry(date: reminder.fireDate, kanji: $0, content: reminder.content)
                }
            }
        return [GlanceEntry(date: now, kanji: current, content: currentContent)] + queued
    }
}
