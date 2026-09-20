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

/// Il formato rettangolare, nella forma che tocca a quel momento: il kanji col suo
/// significato, il kanji da solo, o la parola che lo contiene.
///
/// Niente letture del kanji, mai: è la stessa regola della notifica, se te le dà il
/// quadrante non provi a ricordarle.
public struct GlanceCard: View {
    private let entry: GlanceEntry
    private let viewBox: Double

    public init(entry: GlanceEntry, viewBox: Double) {
        self.entry = entry
        self.viewBox = viewBox
    }

    public var body: some View {
        switch entry.content {
        case .introduce:
            HStack(spacing: DS.Spacing.m) {
                glyph
                Text(verbatim: entry.meaning)
                    .font(.headline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .recall:
            // Solo il kanji, al centro: qui la domanda è il carattere stesso.
            glyph.frame(maxWidth: .infinity)
        case .context:
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: entry.word ?? entry.character)
                    .font(.headline)
                    .dsJapanese()
                Text(verbatim: entry.wordReading ?? "")
                    .font(.caption2)
                    .dsJapanese()
                // Il significato solo se ci sta: su due righe di quadrante la parola
                // e la sua lettura vengono prima.
                Text(verbatim: entry.wordMeaning ?? "")
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var glyph: GlanceGlyph {
        GlanceGlyph(entry: entry, viewBox: viewBox)
    }
}

extension GlanceEntry {
    /// Il formato in linea accetta solo testo: lì il sistema non disegna forme.
    public var inlineLabel: String {
        switch content {
        case .introduce: "\(character) \(meaning)"
        case .recall: character
        case .context: [word, wordReading].compactMap { $0 }.joined(separator: " ")
        }
    }

    /// L'etichetta curva del formato d'angolo. Nella forma del richiamo non c'è:
    /// scrivere la risposta lì sotto sarebbe come non chiederla.
    public var cornerLabel: String? {
        switch content {
        case .introduce: meaning
        case .recall: nil
        case .context: word
        }
    }
}
