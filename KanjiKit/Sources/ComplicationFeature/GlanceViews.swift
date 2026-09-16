import DesignSystem
import KanjiDomain
import SwiftUI

/// Il kanji di una voce della timeline, disegnato dai tratti come nell'app.
///
/// Queste viste non sanno niente di WidgetKit: prendono una voce e la disegnano.
/// Quale vista va su quale formato del quadrante lo decide l'estensione, così qui
/// tutto si può renderizzare e verificare in un test su Mac.
public struct GlanceGlyph: View {
    private let entry: GlanceEntry
    private let glyph: StrokeGlyph?

    public init(entry: GlanceEntry, viewBox: Double) {
        self.entry = entry
        self.glyph = try? StrokeGlyph(svgPaths: entry.strokes, viewBox: viewBox)
    }

    public var body: some View {
        if let glyph {
            KanjiGlyphMark(glyph: glyph)
        } else {
            // Tracciati illeggibili: meglio il carattere che un cerchio vuoto.
            Text(verbatim: entry.character)
                .font(.title2)
                .dsJapanese()
        }
    }
}

/// Il formato rettangolare: kanji e significato, niente letture. È la stessa regola
/// della notifica: se le letture te le dà il quadrante, non provi a ricordarle.
public struct GlanceCard: View {
    private let entry: GlanceEntry
    private let viewBox: Double

    public init(entry: GlanceEntry, viewBox: Double) {
        self.entry = entry
        self.viewBox = viewBox
    }

    public var body: some View {
        HStack(spacing: DS.Spacing.m) {
            GlanceGlyph(entry: entry, viewBox: viewBox)
            Text(verbatim: entry.meaning)
                .font(.headline)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

extension GlanceEntry {
    /// Il formato in linea accetta solo testo: lì il sistema non disegna forme.
    public var inlineLabel: String {
        "\(character) \(meaning)"
    }
}
