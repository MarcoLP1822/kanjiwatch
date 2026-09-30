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

    /// Lo stesso mazzo con al più `count` parole per kanji: le prime, che sono le
    /// migliori. Serve alla versione gratuita, che ne usa tre delle cinque.
    public func keepingWords(_ count: Int) -> KanjiDeck {
        KanjiDeck(
            viewBox: viewBox,
            attribution: attribution,
            kanji: kanji.map { k in
                guard k.words.count > count else { return k }
                return Kanji(
                    character: k.character, codepoint: k.codepoint, strokes: k.strokes, strokeEnds: k.strokeEnds,
                    onReadings: k.onReadings, kunReadings: k.kunReadings, meanings: k.meanings,
                    shortMeanings: k.shortMeanings, words: Array(k.words.prefix(count)), grade: k.grade,
                    frequencyRank: k.frequencyRank)
            }
        )
    }
}
