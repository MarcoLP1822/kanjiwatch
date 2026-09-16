import Foundation

/// Un kanji come lo consuma l'app. Del formato su disco qui non c'è traccia:
/// la mappatura dal JSON vive in KanjiData, così il dominio non si muove
/// se un giorno cambia lo schema dei dati.
public struct Kanji: Identifiable, Hashable, Sendable {
    /// Il carattere, es. "水".
    public let character: String
    /// Codepoint a 5 cifre esadecimali, es. "06c34".
    /// È l'identificatore stabile: viaggia dentro le notifiche.
    public let codepoint: String
    /// Tracciati SVG nell'ordine di scrittura, nel sistema di coordinate del deck.
    public let strokes: [String]
    public let onReadings: [String]
    public let kunReadings: [String]
    public let meanings: [String]
    /// La parola più comune che contiene questo kanji, se JMdict ne ha una.
    public let commonWord: Word?
    /// Anno scolastico giapponese (1-6 kyōiku, 8 jōyō, oltre: jinmeiyō).
    public let grade: Int?
    /// Rango di frequenza nei giornali: 1 è il più comune.
    public let frequencyRank: Int?

    public var id: String { codepoint }
    public var strokeCount: Int { strokes.count }

    public init(
        character: String,
        codepoint: String,
        strokes: [String],
        onReadings: [String],
        kunReadings: [String],
        meanings: [String],
        commonWord: Word? = nil,
        grade: Int? = nil,
        frequencyRank: Int? = nil
    ) {
        self.character = character
        self.codepoint = codepoint
        self.strokes = strokes
        self.onReadings = onReadings
        self.kunReadings = kunReadings
        self.meanings = meanings
        self.commonWord = commonWord
        self.grade = grade
        self.frequencyRank = frequencyRank
    }
}

extension Kanji {
    /// Una parola di esempio: grafia, lettura in kana e significati.
    public struct Word: Hashable, Sendable {
        public let text: String
        public let reading: String
        public let meanings: [String]

        public init(text: String, reading: String, meanings: [String]) {
            self.text = text
            self.reading = reading
            self.meanings = meanings
        }
    }
}
