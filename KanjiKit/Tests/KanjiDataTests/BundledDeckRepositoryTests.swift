import KanjiDomain
import Testing

@testable import KanjiData

@Suite("Mazzo nel bundle")
struct BundledDeckRepositoryTests {
    private let repository = BundledDeckRepository()

    @Test func catalogListsTheWholeJoyoByGrade() throws {
        let catalog = try repository.loadCatalog()
        #expect(catalog.levels.map(\.grade) == [1, 2, 3, 4, 5, 6, 8])
        #expect(catalog.totalCount == 2136)
        #expect(catalog.viewBox == 109)
        // CC BY-SA: se l'attribuzione sparisce dal catalogo, l'app è fuori licenza.
        #expect(catalog.attribution.contains("KanjiVG"))
        #expect(catalog.attribution.contains("EDRDG"))
    }

    /// Il mazzo gratuito è quello che si decodifica all'avvio: deve contenere
    /// solo le prime due classi.
    @Test func loadsOnlyTheRequestedGrades() throws {
        let free = try repository.loadDeck(grades: KanjiLevel.freeGrades)
        #expect(free.kanji.count == 240)
        #expect(free.kanji.allSatisfy { KanjiLevel.freeGrades.contains($0.grade ?? 0) })
    }

    @Test func mapsEveryFieldOfTheMostFrequentKanji() throws {
        let day = try #require(try repository.loadDeck(grades: [1])["065e5"])
        #expect(day.character == "日")
        #expect(day.strokeCount == 4)
        #expect(day.onReadings.contains("ニチ"))
        #expect(day.kunReadings.contains("ひ"))
        #expect(day.meanings.contains("day"))
        #expect(day.grade == 1)
        #expect(day.frequencyRank == 1)
        #expect(day.strokeEnds == [.stop, .stop, .stop, .stop])

        let word = try #require(day.commonWord)
        #expect(word.text.contains("日"))
        #expect(!word.reading.isEmpty)
        #expect(!word.meanings.isEmpty)
    }

    /// Ogni schermata dell'app dà per scontate queste cose: meglio scoprirlo qui
    /// che con un kanji vuoto sul polso.
    @Test func everyKanjiIsUsableOnScreen() throws {
        let deck = try repository.loadDeck()
        #expect(deck.kanji.count == 2136)
        for kanji in deck.kanji {
            #expect(!kanji.strokes.isEmpty, "\(kanji.character): nessun tratto")
            #expect(kanji.strokeEnds.count == kanji.strokeCount, "\(kanji.character): fini dei tratti")
            #expect(!kanji.meanings.isEmpty, "\(kanji.character): nessun significato")
            #expect(kanji.codepoint.count == 5, "\(kanji.character): codepoint \(kanji.codepoint)")
            #expect(
                !kanji.onReadings.isEmpty || !kanji.kunReadings.isEmpty,
                "\(kanji.character): nessuna lettura"
            )
        }
    }

    /// I tipi di KanjiVG per 水: uncino, poi tre spazzate.
    @Test func carriesHowEachStrokeEnds() throws {
        let water = try #require(try repository.loadDeck(grades: [1])["06c34"])
        #expect(water.strokeEnds == [.hook, .sweep, .sweep, .sweep])
    }

    @Test func aMissingGradeFileIsAnExplicitError() {
        let empty = BundledDeckRepository(bundle: .main)
        #expect(throws: DeckLoadingError.fileMissing("kanji-catalog")) {
            try empty.loadCatalog()
        }
    }
}
