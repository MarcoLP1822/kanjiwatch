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
    /// Come finisce ogni tratto, nello stesso ordine di `strokes`. Vuoto se i dati non
    /// lo dicono: chi disegna tratta allora ogni tratto come un fermo.
    public let strokeEnds: [StrokeEnd]
    public let onReadings: [String]
    public let kunReadings: [String]
    public let meanings: [String]
    /// Fino a tre parole che contengono questo kanji, dalla più comune. Vuoto se
    /// JMdict non ne ha nessuna che valga come esempio.
    public let words: [Word]
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
        strokeEnds: [StrokeEnd] = [],
        onReadings: [String],
        kunReadings: [String],
        meanings: [String],
        words: [Word] = [],
        grade: Int? = nil,
        frequencyRank: Int? = nil
    ) {
        self.character = character
        self.codepoint = codepoint
        self.strokes = strokes
        self.strokeEnds = strokeEnds
        self.onReadings = onReadings
        self.kunReadings = kunReadings
        self.meanings = meanings
        self.words = words
        self.grade = grade
        self.frequencyRank = frequencyRank
    }
}

extension Kanji {
    /// La parola più comune: quella che si mostra quando nessuno ne ha scelta
    /// un'altra.
    public var commonWord: Word? { words.first }

    /// La parola di quell'esposizione. Un indice che non c'è più — il mazzo è stato
    /// rigenerato con meno parole dopo che la notifica era stata programmata — torna
    /// alla più comune invece di lasciare la notifica senza parola.
    public func word(for reference: ExposureReference) -> Word? {
        if case .word(let index) = reference, words.indices.contains(index) {
            return words[index]
        }
        return commonWord
    }

    /// Come si chiude un tratto a pennello. Lo decide la calligrafia, non la forma del
    /// tracciato: dedurlo dal disegno sbaglia un tratto su tre.
    public enum StrokeEnd: Sendable, Hashable {
        /// Tome: il pennello si ferma.
        case stop
        /// Harai: il pennello si solleva spazzando e il tratto si assottiglia.
        case sweep
        /// Hane: il pennello cambia direzione di scatto.
        case hook
        /// Ten: il punto.
        case dot
    }

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
