import SwiftUI

/// Il kanji ridotto ai soli tratti: niente alone, niente sagoma guida, niente colori
/// nostri.
///
/// Serve dove lo spazio è minuscolo e il colore lo decide il sistema, come sulle
/// complication, che il quadrante tinge a modo suo: il colore arriva dallo stile in
/// primo piano.
public struct KanjiGlyphMark: View {
    /// Quasi il doppio del glifo a tutto schermo: a 40 punti un tratto sottile sparisce.
    public static let widthRatio: CGFloat = 6.5 / 109

    private let glyph: StrokeGlyph

    public init(glyph: StrokeGlyph) {
        self.glyph = glyph
    }

    public var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            GlyphShape(sources: glyph.strokes.map(\.path), viewBox: glyph.viewBox)
                .stroke(.foreground, style: DS.Stroke.style(forSide: side, ratio: Self.widthRatio))
                .frame(width: side, height: side)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

#if DEBUG
#Preview("Solo tratti") {
    KanjiGlyphMark(glyph: .previewWater)
        .frame(width: 44, height: 44)
        .foregroundStyle(.white)
        .padding()
        .background(.black)
}
#endif
