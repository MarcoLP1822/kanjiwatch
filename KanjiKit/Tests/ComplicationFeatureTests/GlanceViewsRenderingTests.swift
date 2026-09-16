#if os(macOS)
import KanjiData
import KanjiDomain
import KanjiTestSupport
import SwiftUI
import Testing

@testable import ComplicationFeature

/// Le complication a misura di quadrante, in bianco su nero come le tinge il
/// sistema: si guardano, non si immaginano.
@Suite("Rendering della complication")
@MainActor
struct GlanceViewsRenderingTests {
    private func waterEntry() throws -> (GlanceEntry, Double) {
        let deck = try BundledDeckRepository().loadDeck(grades: [1])
        let water = try #require(deck["06c34"])
        return (GlanceEntry(date: .now, kanji: water), deck.viewBox)
    }

    private func onWatchFace(_ view: some View) -> some View {
        view
            .foregroundStyle(.white)
            .background(.black)
    }

    @Test func drawsTheKanjiInTheRoundComplication() throws {
        let (entry, viewBox) = try waterEntry()
        let circular = try renderImage(
            onWatchFace(GlanceGlyph(entry: entry, viewBox: viewBox).padding(6)),
            size: CGSize(width: 50, height: 50),
            named: "complication-circular"
        )
        #expect(inkPixels(circular) > 100)
    }

    @Test func showsKanjiAndMeaningButNoReadingsInTheRectangle() throws {
        let (entry, viewBox) = try waterEntry()
        let rectangular = try renderImage(
            onWatchFace(GlanceCard(entry: entry, viewBox: viewBox)),
            size: CGSize(width: 180, height: 56),
            named: "complication-rectangular"
        )
        #expect(inkPixels(rectangular) > 300)
        #expect(entry.inlineLabel == "水 water")
    }
}
#endif
