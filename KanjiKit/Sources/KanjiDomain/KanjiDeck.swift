import Foundation

/// Il mazzo caricato all'avvio: ordine stabile per la UI, lookup O(1) per le notifiche
/// (arriva un codepoint e serve il kanji, subito).
public struct KanjiDeck: Sendable {
    /// Lato del quadrato in cui vivono i tracciati: KanjiVG usa 109.
    /// È l'unico numero magico del progetto e sta solo qui.
    public let viewBox: Double
    /// Testo di licenza delle fonti: CC BY-SA obbliga a mostrarlo dentro l'app.
    public let attribution: String
    public let kanji: [Kanji]

    private let index: [String: Kanji]

    public init(viewBox: Double, attribution: String, kanji: [Kanji]) {
        self.viewBox = viewBox
        self.attribution = attribution
        self.kanji = kanji
        self.index = Dictionary(kanji.map { ($0.codepoint, $0) }, uniquingKeysWith: { first, _ in first })
    }

    public subscript(codepoint: String) -> Kanji? { index[codepoint] }

    public var codepoints: [String] { kanji.map(\.codepoint) }
    public var isEmpty: Bool { kanji.isEmpty }
}
