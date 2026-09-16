import Foundation
import KanjiDomain

/// Lo schema di kanji.json, con i nomi corti che usa lo script Python.
/// Vive qui e solo qui: se cambia il formato dei dati si tocca questo file
/// e il dominio non se ne accorge.
struct DeckFile: Decodable {
    /// Unica lingua dei significati nel file generato (`--langs en`).
    static let meaningLanguage = "en"

    let version: Int
    let viewBox: Double
    let attribution: String
    let kanji: [Entry]

    struct Entry: Decodable {
        let c: String
        let cp: String
        let strokes: [String]
        let on: [String]
        let kun: [String]
        let meanings: [String: [String]]
        let word: Word?
        let grade: Int?
        let freq: Int?

        struct Word: Decodable {
            let w: String
            let r: String
            let g: [String]
        }
    }
}

extension DeckFile {
    func toDomain() -> KanjiDeck {
        KanjiDeck(viewBox: viewBox, attribution: attribution, kanji: kanji.map { $0.toDomain() })
    }
}

extension DeckFile.Entry {
    func toDomain() -> Kanji {
        Kanji(
            character: c,
            codepoint: cp,
            strokes: strokes,
            onReadings: on,
            kunReadings: kun,
            meanings: meanings[DeckFile.meaningLanguage] ?? [],
            commonWord: word.map { Kanji.Word(text: $0.w, reading: $0.r, meanings: $0.g) },
            grade: grade,
            frequencyRank: freq
        )
    }
}
