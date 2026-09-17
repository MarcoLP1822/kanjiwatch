import SwiftUI
import Testing

@testable import DesignSystem

@Suite("Tratto a pennello")
struct BrushStrokeTests {
    /// Un tratto orizzontale lungo 100, a metà altezza.
    private let straight = (0...20).map { CGPoint(x: Double($0) * 5, y: 50) }
    private let square = CGRect(x: 0, y: 0, width: 109, height: 109)

    private func bounds(_ fraction: Double, _ ending: StrokeGlyph.Ending = .stop) -> CGRect {
        BrushStroke(samples: straight, viewBox: 109, ending: ending, fraction: fraction).path(in: square).boundingRect
    }

    /// Le spazzate finiscono in punta, gli uncini quasi, i fermi restano pieni.
    @Test func endingsCloseTheStrokeDifferently() {
        #expect(BrushStroke.width(at: 1, ending: .sweep) < 0.1)
        #expect(BrushStroke.width(at: 1, ending: .hook) < 0.25)
        #expect(BrushStroke.width(at: 1, ending: .stop) > 0.9)
        // Il punto è una goccia: più largo verso la fine che all'attacco.
        #expect(BrushStroke.width(at: 0.6, ending: .dot) > BrushStroke.width(at: 0, ending: .dot) * 2)
    }

    /// Il pennello entra leggero e poi preme.
    @Test func theBrushEntersLightly() {
        #expect(BrushStroke.width(at: 0, ending: .stop) < BrushStroke.width(at: 0.3, ending: .stop))
    }

    @Test func drawsOnlyTheWrittenPart() {
        #expect(BrushStroke(samples: straight, viewBox: 109, ending: .stop, fraction: 0).path(in: square).isEmpty)
        // A metà la punta sta a 50, più il raggio della punta arrotondata.
        #expect(abs(bounds(0.5).maxX - 50) < 5)
        #expect(bounds(1).maxX > 100)
    }

    /// Nessun punto del tratto è più spesso del massimo previsto dal token.
    @Test func neverThickerThanTheToken() {
        #expect(bounds(1).height <= 109 * DS.Brush.widthRatio * 1.2)
        #expect(bounds(1, .sweep).height <= bounds(1, .stop).height)
    }
}
