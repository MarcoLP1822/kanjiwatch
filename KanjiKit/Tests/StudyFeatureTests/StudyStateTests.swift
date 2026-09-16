import Testing

@testable import StudyFeature

@Suite("Macchina a stati dello studio")
struct StudyStateTests {
    private func makeState(strokes: Int = 4) -> StudyState {
        StudyState(strokeCount: strokes)
    }

    @Test func startsOnTheWholeKanji() {
        let state = makeState()
        #expect(state.phase == .glyph)
        #expect(state.progress == 4)
        #expect(!state.isDrawing)
    }

    @Test func tapRedrawsFromTheFirstStroke() {
        var state = makeState()
        #expect(state.handle(.tapped) == .startDrawing)
        #expect(state.progress == 0)
        #expect(state.isDrawing)
    }

    /// Chi tocca due volte di fretta vuole il kanji finito, non le letture.
    @Test func tapDuringDrawingCompletesItWithoutRevealing() {
        var state = makeState()
        state.handle(.tapped)
        #expect(state.handle(.tapped) == .holdThenReveal)
        #expect(state.progress == 4)
        #expect(state.phase == .glyph)
    }

    @Test func readingsAppearOnlyAfterTheHold() {
        var state = makeState()
        state.handle(.tapped)
        #expect(state.handle(.drawingFinished) == .holdThenReveal)
        #expect(state.phase == .glyph)
        state.handle(.holdElapsed)
        #expect(state.phase == .readings)
    }

    @Test func tapFromReadingsGoesBackToTheWholeKanji() {
        var state = makeState()
        state.handle(.tapped)
        state.handle(.drawingFinished)
        state.handle(.holdElapsed)
        #expect(state.handle(.tapped) == .none)
        #expect(state.phase == .glyph)
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
        #expect(state.progress == 3)
    }

    @Test func crownTakesOverFromTheAnimation() {
        var state = makeState()
        state.handle(.tapped)
        #expect(state.handle(.crownMoved(to: 2.5)) == .stopDrawing)
        #expect(state.progress == 2.5)
        #expect(!state.isDrawing)
    }

    @Test func crownStaysWithinTheStrokesAndRevealsNothing() {
        var state = makeState()
        #expect(state.handle(.crownMoved(to: 9)) == .none)
        #expect(state.progress == 4)
        #expect(state.phase == .glyph)
    }

    /// L'attesa arriva sempre in ritardo: se nel frattempo hai fatto ripartire il
    /// disegno, non deve portarti alle letture sotto il naso.
    @Test func staleHoldIsIgnoredWhenDrawingStartedAgain() {
        var state = makeState()
        state.handle(.tapped)
        state.handle(.drawingFinished)
        state.handle(.tapped)
        state.handle(.holdElapsed)
        #expect(state.phase == .glyph)
        #expect(state.isDrawing)
    }
}
