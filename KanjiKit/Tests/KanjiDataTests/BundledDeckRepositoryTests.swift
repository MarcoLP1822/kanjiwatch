import KanjiDomain
import Testing

@testable import KanjiData

@Suite("Deck nel bundle")
struct BundledDeckRepositoryTests {
    private func loadDeck() throws -> KanjiDeck {
        try BundledDeckRepository().loadDeck()
    }

    @Test func loadsTheGeneratedDeck() throws {
        let deck = try loadDeck()
        #expect(deck.kanji.count == 300)
        #expect(deck.viewBox == 109)
        // CC BY-SA: se l'attribuzione sparisce dal JSON, l'app è fuori licenza.
        #expect(deck.attribution.contains("KanjiVG"))
        #expect(deck.attribution.contains("EDRDG"))
    }

    @Test func mapsEveryFieldOfTheMostFrequentKanji() throws {
        let day = try #require(try loadDeck()["065e5"])
        #expect(day.character == "日")
        #expect(day.strokeCount == 4)
        #expect(day.onReadings.contains("ニチ"))
        #expect(day.kunReadings.contains("ひ"))
        #expect(day.meanings.contains("day"))
        #expect(day.frequencyRank == 1)

        let word = try #require(day.commonWord)
        #expect(word.text.contains("日"))
        #expect(!word.reading.isEmpty)
        #expect(!word.meanings.isEmpty)
    }

    /// Ogni schermata dell'app dà per scontate queste cose: meglio scoprirlo qui
    /// che con un kanji vuoto sul polso.
    @Test func everyKanjiIsUsableOnScreen() throws {
        for kanji in try loadDeck().kanji {
            #expect(!kanji.strokes.isEmpty, "\(kanji.character): nessun tratto")
            #expect(!kanji.meanings.isEmpty, "\(kanji.character): nessun significato")
            #expect(kanji.codepoint.count == 5, "\(kanji.character): codepoint \(kanji.codepoint)")
            #expect(
                !kanji.onReadings.isEmpty || !kanji.kunReadings.isEmpty,
                "\(kanji.character): nessuna lettura"
            )
        }
    }
}
