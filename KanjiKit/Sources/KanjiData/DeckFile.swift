import Foundation
import KanjiDomain

/// Lo schema dei file generati dallo script Python, con i suoi nomi corti.
/// Vive qui e solo qui: se cambia il formato si tocca questo file e il dominio non
/// se ne accorge.

/// `kanji-catalog.json`: cosa c'è nel bundle, senza un solo kanji dentro.
struct CatalogFile: Decodable {
    let version: Int
    let viewBox: Double
    let attribution: String
    let levels: [Level]

    struct Level: Decodable {
        let grade: Int
        let count: Int
    }

    func toDomain() -> DeckCatalog {
        DeckCatalog(
            viewBox: viewBox,
            attribution: attribution,
            levels: levels.map { KanjiLevel(grade: $0.grade, count: $0.count) }
        )
    }
}

/// `kanji-grade-N.json`: i kanji di un grado scolastico, tratti compresi.
struct LevelFile: Decodable {
    /// Unica lingua dei significati nei file generati (`--langs en`).
    static let meaningLanguage = "en"

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

        func toDomain() -> Kanji {
            Kanji(
                character: c,
                codepoint: cp,
                strokes: strokes,
                onReadings: on,
                kunReadings: kun,
                meanings: meanings[LevelFile.meaningLanguage] ?? [],
                commonWord: word.map { Kanji.Word(text: $0.w, reading: $0.r, meanings: $0.g) },
                grade: grade,
                frequencyRank: freq
            )
        }
    }
}
