import Foundation
import KanjiDomain
import Testing

@testable import KanjiData

@Suite("Mazzo nel bundle")
struct BundledDeckRepositoryTests {
    private let repository = BundledDeckRepository()

    /// Fino a tre parole per kanji, tutte diverse e tutte col kanji dentro: sono
    /// quelle che la forma col contesto farà girare sul quadrante.
    @Test func everyKanjiHasUpToThreeDistinctWordsThatContainIt() throws {
        let catalog = try repository.loadCatalog()
        let all = try repository.loadDeck(grades: Set(catalog.levels.map(\.grade)))

        for kanji in all.kanji {
            #expect(kanji.words.count <= 3, "\(kanji.character): \(kanji.words.count) parole")
            #expect(kanji.words.allSatisfy { $0.text.contains(kanji.character) }, "\(kanji.character)")
            #expect(Set(kanji.words.map(\.text)).count == kanji.words.count, "\(kanji.character): doppioni")
        }
        // Quasi tutti ne hanno tre: è lì che sta la profondità.
        #expect(all.kanji.count { $0.words.count == 3 } > 2000)
    }

    /// Lo schema 3 porta la lista; lo schema 2, di prima, una parola sola. Tutti e due
    /// si leggono, così un bundle o una fixture non rigenerati non restano senza parola.
    @Test func readsBothTheNewAndTheOldWordSchema() throws {
        let v3 = #"""
            {"kanji":[{"c":"水","cp":"06c34","strokes":["M0,0"],"on":[],"kun":[],"meanings":{"en":["water"]},
            "words":[{"w":"水曜日","r":"すいようび","g":["Wednesday"]},{"w":"水着","r":"みずぎ","g":["bathing suit"]}]}]}
            """#
        let v2 = #"""
            {"kanji":[{"c":"水","cp":"06c34","strokes":["M0,0"],"on":[],"kun":[],"meanings":{"en":["water"]},
            "word":{"w":"水曜日","r":"すいようび","g":["Wednesday"]}}]}
            """#
        let none = #"""
            {"kanji":[{"c":"且","cp":"04e14","strokes":["M0,0"],"on":[],"kun":[],"meanings":{"en":["also"]}}]}
            """#

        let decode = { (json: String) throws -> Kanji in
            try #require(try JSONDecoder().decode(LevelFile.self, from: Data(json.utf8)).kanji.first).toDomain()
        }
        #expect(try decode(v3).words.map(\.text) == ["水曜日", "水着"])
        #expect(try decode(v2).words.map(\.text) == ["水曜日"])
        #expect(try decode(v2).commonWord?.reading == "すいようび")
        #expect(try decode(none).words.isEmpty)
    }

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
