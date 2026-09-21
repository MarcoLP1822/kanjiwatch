import Foundation
import KanjiDomain
import Testing

@testable import StudyFeature

@Suite("Modello della schermata")
@MainActor
struct StudyViewModelTests {
    private let deck = KanjiDeck(
        viewBox: 109,
        attribution: "",
        kanji: [
            waterKanji,
            Kanji(
                character: "火", codepoint: "0706b", strokes: ["M0,0c1,1,2,2,3,3"], onReadings: [], kunReadings: [],
                meanings: ["fire"]),
        ]
    )

    /// NEXT riparte dal kanji intero, e chiede di rifare la coda da adesso.
    @Test func nextStartsAFreshTurnAndAsksForANewQueue() {
        var clock = Date(timeIntervalSince1970: 1_800_000_000)
        let model = makeStudyModel(deck: deck, now: { clock })
        var advances = 0
        model.onAdvance = { advances += 1 }
        let first = model.kanji
        model.send(.tapped)
        model.send(.drawingFinished)
        model.send(.tapped)

        clock += 60
        model.next()

        #expect(model.kanji != first)
        #expect(model.state.phase == .kanji)
        #expect(advances == 1)
    }

    /// DONE porta all'attesa senza cambiare kanji; rileggere lo stato non lo riapre.
    @Test func doneWaitsOnTheSameKanji() {
        let model = makeStudyModel(deck: deck)
        let studied = model.kanji

        model.done()
        model.refresh()

        #expect(model.snapshot.isDone)
        #expect(model.kanji == studied)
    }

    /// Il permesso si chiede una volta sola, la prima volta che arrivi alle letture.
    @Test func readingsAskForThePermissionOnce() {
        var clock = Date(timeIntervalSince1970: 1_800_000_000)
        let model = makeStudyModel(deck: deck, now: { clock })
        var asked = 0
        model.onReadingsFirstShown = { asked += 1 }

        for _ in 0..<2 {
            model.send(.tapped)
            model.send(.drawingFinished)
            model.send(.tapped)
            clock += 60
            model.next()
        }

        #expect(asked == 1)
    }

    /// Aperta dalla notifica che mostrava 水着, l'app porta 水着 fino alle letture:
    /// mai la notifica su una parola e la schermata su un'altra.
    @Test func openingFromAWordKeepsThatWordForTheReadings() {
        let model = makeStudyModel(deck: deck)

        model.open(ReminderDestination(codepoint: waterKanji.codepoint, content: .context, reference: .word(1)))

        #expect(model.snapshot.reference == .word(1))
        #expect(model.kanji.word(for: model.snapshot.reference)?.text == "水着")
    }

    /// Il permesso si chiede una volta, ma il segnale si registra ogni volta: è
    /// quello che dice al motore quali kanji ti interessano davvero.
    @Test func everyTimeYouReachTheReadingsItIsRecorded() throws {
        var clock = Date(timeIntervalSince1970: 1_800_000_000)
        let ambient = InMemoryStore(AmbientState.empty)
        let model = makeStudyModel(deck: deck, ambient: ambient, now: { clock })
        let studied = model.kanji

        for _ in 0..<2 {
            model.send(.tapped)
            model.send(.drawingFinished)
            model.send(.tapped)
            clock += 60
            model.next()
            clock += 60
        }

        #expect(ambient.value.records[studied.codepoint]?.readingsViewedCount == 1)
        #expect(ambient.value.records.values.map(\.readingsViewedCount).reduce(0, +) == 2)
    }
}
