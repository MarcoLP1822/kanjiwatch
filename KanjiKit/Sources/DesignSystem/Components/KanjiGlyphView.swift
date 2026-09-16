import SwiftUI

/// Il kanji disegnato tratto per tratto.
///
/// `progress` va da 0 a `strokeCount`: la parte intera sono i tratti finiti, la
/// parte decimale è quanto è disegnato quello in corso. Un solo numero anima tutto,
/// e siccome la view è `Animatable` può animarlo SwiftUI o guidarlo la corona.
///
/// È un elemento decorativo: l'etichetta di accessibilità la mette chi la usa,
/// che conosce il carattere e il significato.
public struct KanjiGlyphView: View {
    private let glyph: StrokeGlyph
    private var progress: Double

    public init(glyph: StrokeGlyph, progress: Double) {
        self.glyph = glyph
        self.progress = progress
    }

    public var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let style = DS.Stroke.style(forSide: side)

            ZStack {
                RadialGradient(
                    colors: [.dsAccent.opacity(DS.Stroke.haloOpacity), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: side * 0.58
                )

                // Sagoma completa: dice dove andranno i tratti mancanti senza
                // rivelarli davvero. Un solo Shape per tutti, non venti.
                GlyphShape(sources: glyph.strokes.map(\.path), viewBox: glyph.viewBox)
                    .stroke(Color.dsAccent.opacity(DS.Stroke.guideOpacity), style: style)

                ForEach(Array(glyph.strokes.enumerated()), id: \.offset) { index, stroke in
                    GlyphShape(sources: [stroke.path], viewBox: glyph.viewBox)
                        .trim(from: 0, to: drawnFraction(at: index))
                        .stroke(color(at: index), style: style)
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func drawnFraction(at index: Int) -> CGFloat {
        CGFloat(min(max(progress - Double(index), 0), 1))
    }

    /// Il tratto in corso è acceso, quelli finiti sono inchiostro: così si vede
    /// dove sta scrivendo la mano.
    private func color(at index: Int) -> Color {
        drawnFraction(at: index) < 1 ? .dsAccent : .dsInk
    }
}

extension KanjiGlyphView: Animatable {
    public var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }
}

/// Porta i tracciati dal quadrato di KanjiVG a quello sullo schermo.
/// La scala si applica alla `Path`, non con `scaleEffect`: quello scalerebbe anche
/// lo spessore del tratto, e su un quadrante piccolo si nota.
struct GlyphShape: Shape {
    let sources: [Path]
    let viewBox: Double

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / viewBox
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        var combined = Path()
        for source in sources {
            combined.addPath(source, transform: transform)
        }
        return combined
    }
}

#if DEBUG
#Preview("Glifo completo") {
    KanjiGlyphView(glyph: .previewWater, progress: 4)
        .padding(DS.Spacing.l)
        .background(Color.dsBackground)
}

#Preview("Terzo tratto a metà") {
    KanjiGlyphView(glyph: .previewWater, progress: 2.5)
        .padding(DS.Spacing.l)
        .background(Color.dsBackground)
}
#endif
