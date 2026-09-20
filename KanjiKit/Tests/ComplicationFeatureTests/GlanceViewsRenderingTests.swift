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
    private func waterEntry(_ content: ExposureContent = .introduce) throws -> (GlanceEntry, Double) {
        let deck = try BundledDeckRepository().loadDeck(grades: [1])
        let water = try #require(deck["06c34"])
        return (GlanceEntry(date: .now, kanji: water, content: content), deck.viewBox)
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

    /// Le tre forme sul rettangolo: il significato, il kanji da solo, la parola.
    @Test func theRectangleFollowsTheSequence() throws {
        let (introduce, viewBox) = try waterEntry()
        let (recall, _) = try waterEntry(.recall)
        let (context, _) = try waterEntry(.context)

        let sizes = try [introduce, recall, context].map { entry in
            inkPixels(
                try renderImage(
                    onWatchFace(GlanceCard(entry: entry, viewBox: viewBox)),
                    size: CGSize(width: 180, height: 56),
                    named: "complication-rectangular-\(entry.content.rawValue)"
                ))
        }
        // Il richiamo è il più scarno dei tre: solo il glifo, nessuna parola.
        #expect(sizes[1] < sizes[0])
        #expect(sizes[2] > 0)
    }

    /// Il formato in linea è solo testo, e su quella riga ci sta poco: mai la
    /// parola col suo significato in coda.
    @Test func theInlineLabelSaysTheMinimum() throws {
        #expect(try waterEntry(.recall).0.inlineLabel == "水")
        #expect(try waterEntry(.context).0.inlineLabel == "水曜日 すいようび")
    }

    /// Sull'angolo l'etichetta curva è la risposta: nella forma del richiamo non
    /// c'è, altrimenti sarebbe come non chiedere niente.
    @Test func theCornerLabelKeepsTheAnswerHiddenWhenItShould() throws {
        #expect(try waterEntry().0.cornerLabel == "water")
        #expect(try waterEntry(.recall).0.cornerLabel == nil)
        #expect(try waterEntry(.context).0.cornerLabel == "水曜日")
    }
}
#endif
