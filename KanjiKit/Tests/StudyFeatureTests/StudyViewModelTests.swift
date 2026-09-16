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
}
