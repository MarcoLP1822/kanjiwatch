import KanjiDomain
import Testing

@Suite("KanjiDeck")
struct KanjiDeckTests {
    private func kanji(_ character: String, _ codepoint: String) -> Kanji {
        Kanji(
            character: character,
            codepoint: codepoint,
            strokes: ["M0,0"],
            onReadings: [],
            kunReadings: [],
            meanings: ["placeholder"]
        )
    }

    @Test func findsAKanjiByCodepoint() {
        let deck = KanjiDeck(viewBox: 109, attribution: "", kanji: [kanji("水", "06c34"), kanji("火", "0706b")])
        #expect(deck["06c34"]?.character == "水")
        #expect(deck["0ffff"] == nil)
        #expect(deck.codepoints == ["06c34", "0706b"])
    }

    /// Un file di dati malformato non deve far esplodere l'indice all'avvio.
    @Test func keepsTheFirstOfDuplicateCodepoints() {
        let deck = KanjiDeck(viewBox: 109, attribution: "", kanji: [kanji("水", "06c34"), kanji("氷", "06c34")])
        #expect(deck["06c34"]?.character == "水")
        #expect(deck.kanji.count == 2)
    }
}
