import SwiftUI

/// I tratti di un kanji già interpretati. Si parsa una volta sola — quando il kanji
/// entra in scena — e si passa il risultato alle view, che in SwiftUI vengono
/// ricostruite di continuo.
public struct StrokeGlyph: Equatable, Sendable {
    public let strokes: [StrokePath]
    /// Lato del sistema di coordinate dei tracciati (109 per KanjiVG).
    public let viewBox: Double

    public init(svgPaths: [String], viewBox: Double) throws {
        self.strokes = try svgPaths.map { try SVGPathParser.parse($0) }
        self.viewBox = viewBox
    }

    public var strokeCount: Int { strokes.count }

    /// Durata di ogni tratto, proporzionale alla sua lunghezza.
    public var durations: [Double] {
        strokes.map { DS.Motion.strokeDuration(forLength: $0.length) }
    }

    /// Quanto dura l'animazione completa, pause comprese.
    public var totalDuration: Double {
        durations.reduce(0, +) + DS.Motion.strokePause * Double(max(strokeCount - 1, 0))
    }
}

#if DEBUG
extension StrokeGlyph {
    /// I quattro tratti di 水, per preview e test. Sono dati veri di KanjiVG.
    static let previewWater = try! StrokeGlyph(
        svgPaths: [
            "M52.77,15.08c1.08,1.08,1.67,2.49,1.76,5.52c0.4,14.55-0.26,62.16-0.26,67.12c0,9.78-7.52,0.03-9.02-1.22",
            "M17.5,45.75c1.75,0.62,3.73,0.43,5.25,0C25.88,44.88,36.09,41,38.59,40s4.47,1.24,3.75,3.5C39,54,28.25,69,19,74.75",
            "M81.22,27.5c-0.22,1.25-0.72,2.25-1.52,2.97c-5.64,5.1-12.45,9.78-22.45,13.78",
            "M57,46c8.82,10.73,19.23,21.46,28.42,27.42c2.16,1.4,4.52,3,7.08,3.58",
        ],
        viewBox: 109
    )
}
#endif
