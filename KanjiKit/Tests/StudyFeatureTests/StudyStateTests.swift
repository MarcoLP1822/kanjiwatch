import Testing

@testable import StudyFeature

@Suite("Macchina a stati dello studio")
struct StudyStateTests {
    private func makeState(strokes: Int = 4) -> StudyState {
        StudyState(strokeCount: strokes)
    }

    @Test func startsOnTheWholeKanji() {
        let state = makeState()
        #expect(state.phase == .kanji)
        #expect(state.progress == 4)
        #expect(!state.isDrawing)
    }

    /// Il giro completo, un tocco per passo: kanji → tratti → letture.
    @Test func eachTapIsOneStep() {
        var state = makeState()

        #expect(state.handle(.tapped) == .startDrawing)
        #expect(state.phase == .strokes)
        #expect(state.progress == 0)

        state.handle(.drawingFinished)
        #expect(state.phase == .strokes)
        #expect(state.isComplete)

        #expect(state.handle(.tapped) == .none)
        #expect(state.phase == .readings)
    }

    /// Il disegno finito non porta da solo alle letture: si aspetta il tocco.
    @Test func nothingAdvancesByItself() {
        var state = makeState()
        state.handle(.tapped)
        state.handle(.drawingAdvanced(to: 4))
        state.handle(.drawingFinished)
        #expect(state.phase == .strokes)
    }

    /// Chi tocca due volte di fretta vuole il kanji finito, non le letture.
    @Test func tapDuringDrawingCompletesItWithoutRevealing() {
        var state = makeState()
        state.handle(.tapped)
        #expect(state.handle(.tapped) == .stopDrawing)
        #expect(state.progress == 4)
        #expect(state.phase == .strokes)
    }

    /// Nelle letture si esce solo con DONE o NEXT: un tocco qualsiasi non torna ai tratti.
    @Test func tapsOnTheReadingsDoNothing() {
        var state = makeState()
        state.handle(.tapped)
        state.handle(.drawingFinished)
        state.handle(.tapped)

        #expect(state.handle(.tapped) == .none)
        #expect(state.phase == .readings)
        #expect(state.handle(.crownMoved(to: 1)) == .none)
        #expect(state.progress == 4)
    }

    /// Il task del disegno continua a mandare avanzamenti anche dopo che l'hai
    /// interrotto: devono cadere nel vuoto, non riportare indietro il glifo.
    @Test func advancesAreIgnoredOnceDrawingStopped() {
        var state = makeState()
        state.handle(.tapped)
        state.handle(.drawingAdvanced(to: 1))
        #expect(state.progress == 1)

        state.handle(.crownMoved(to: 3))
        state.handle(.drawingAdvanced(to: 2))
        state.handle(.drawingFinished)
        #expect(state.progress == 3)
    }

    @Test func crownTakesOverFromTheAnimation() {
        var state = makeState()
        state.handle(.tapped)
        #expect(state.handle(.crownMoved(to: 2.5)) == .stopDrawing)
        #expect(state.progress == 2.5)
        #expect(!state.isDrawing)
    }

    /// Scorrere i tratti con la corona vale come averli guardati: il tocco dopo
    /// porta alle letture invece di ridisegnare.
    @Test func crownOnTheKanjiCountsAsLookingAtTheStrokes() {
        var state = makeState()
        #expect(state.handle(.crownMoved(to: 9)) == .none)
        #expect(state.progress == 4)
        #expect(state.phase == .strokes)

        state.handle(.tapped)
        #expect(state.phase == .readings)
    }
}
