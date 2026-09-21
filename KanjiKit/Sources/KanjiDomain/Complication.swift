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
    public let reference: ExposureReference
    public let character: String
    public let meaning: String
    public let strokes: [String]
    public let word: String?
    public let wordReading: String?
    public let wordMeaning: String?

    public init(
        date: Date,
        kanji: Kanji,
        content: ExposureContent = .introduce,
        reference: ExposureReference = .none
    ) {
        // La parola si risolve qui, dove il mazzo c'è: l'estensione del quadrante
        // riceve il testo pronto e non deve nemmeno sapere che le parole sono tre.
        let word = kanji.word(for: reference)
        self.date = date
        self.codepoint = kanji.codepoint
        self.content = content.resolved(hasWord: word != nil)
        self.reference = reference
        self.character = kanji.character
        self.meaning = kanji.shortMeaning
        self.strokes = kanji.strokes
        self.word = word?.text
        self.wordReading = word?.reading
        self.wordMeaning = word?.shortMeaning
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
        reference = (try? container.decodeIfPresent(ExposureReference.self, forKey: .reference)) ?? .none
    }

    public var destination: ReminderDestination {
        ReminderDestination(codepoint: codepoint, content: content, reference: reference)
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
        currentReference: ExposureReference = .none,
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
                    GlanceEntry(
                        date: reminder.fireDate, kanji: $0, content: reminder.content, reference: reminder.reference)
                }
            }
        return [GlanceEntry(date: now, kanji: current, content: currentContent, reference: currentReference)] + queued
    }
}
