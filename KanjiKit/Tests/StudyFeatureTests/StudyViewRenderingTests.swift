#if os(macOS)
import AppKit
import DesignSystem
import KanjiDomain
import SwiftUI
import Testing

@testable import StudyFeature

/// La schermata renderizzata a misura di quadrante, per guardarla invece di
/// immaginarla.
///
/// Nota: `swift test` da riga di comando non compila i String Catalog, quindi
/// nelle immagini le scritte appaiono nella lingua sorgente (inglese).
@Suite("Rendering della schermata")
@MainActor
struct StudyViewRenderingTests {

    @Test func drawsBothPhasesDifferently() throws {
        let glyph = try renderWatchSized(StudyView(model: StudyViewModel(deck: waterDeck)), named: "study-glyph")

        let model = StudyViewModel(deck: waterDeck)
        model.send(.tapped)
        model.send(.drawingFinished)
        model.send(.holdElapsed)
        #expect(model.state.phase == .readings)

        // Il contenuto senza ScrollView: dentro una ScrollView ImageRenderer
        // restituisce un'immagine vuota.
        let revealed = try renderWatchSized(
            ReadingsContent(kanji: model.kanji, glyph: model.glyph, onNext: {})
                .padding(DS.Spacing.m)
                .background(Color.dsBackground),
            named: "study-readings"
        )

        // Le due fasi devono disegnare cose diverse, e nessuna delle due può
        // essere una schermata vuota.
        #expect(inkPixels(glyph) > 500)
        #expect(inkPixels(revealed) > 500)
        #expect(inkPixels(glyph) != inkPixels(revealed))
    }
}
#endif
