import DesignSystem
import KanjiDomain
import SwiftUI

/// Il contenuto della notifica, in una delle tre forme della micro-sequenza.
///
/// Niente letture del kanji, di proposito. Se la notifica te le dà subito non provi
/// a ricordarle, e il ripasso — che è tutto il punto dell'app — non avviene.
public struct ReminderGlanceView: View {
    private let kanji: Kanji?
    private let glyph: StrokeGlyph?
    private let content: ExposureContent
    /// La parola scelta dal piano per questo momento, già risolta.
    private let word: Kanji.Word?
    private let theme: DSTheme

    /// Il tema arriva come parametro: la notifica la mostra il sistema, fuori dalla
    /// gerarchia di view dell'app, e l'ambiente dell'app qui non arriva.
    public init(
        kanji: Kanji?,
        viewBox: Double,
        content: ExposureContent = .introduce,
        reference: ExposureReference = .none,
        theme: DSTheme = .aiZome
    ) {
        self.kanji = kanji
        self.glyph = kanji.flatMap { try? StrokeGlyph(kanji: $0, viewBox: viewBox) }
        self.word = kanji?.word(for: reference)
        self.content = content.resolved(hasWord: word != nil)
        self.theme = theme
    }

    public var body: some View {
        VStack(spacing: DS.Spacing.s) {
            if let word, content == .context {
                context(word)
            } else {
                character
                if let kanji, content == .introduce {
                    Text(verbatim: kanji.shortMeaning)
                        .font(.dsLabel)
                        .foregroundStyle(.dsInkSecondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(DS.Spacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.dsBackground)
        .dsTheme(theme)
    }

    /// Il kanji e basta. Nella forma `recall` è tutto quello che c'è: mezzo secondo
    /// per pensarci, e scrivere "ricordi?" sarebbe rumore su uno schermo così.
    @ViewBuilder
    private var character: some View {
        if let glyph {
            KanjiGlyphView(glyph: glyph, progress: Double(glyph.strokeCount))
        } else if let kanji {
            // Tracciati illeggibili: il carattere si vede comunque.
            Text(verbatim: kanji.character)
                .font(.system(size: 64))
                .foregroundStyle(.dsInk)
                .dsJapanese()
        }
    }

    /// Il kanji dentro una parola vera, con la lettura in kana. Qui il carattere non
    /// si disegna: la parola è il punto, e il kanji si riconosce perché è acceso.
    private func context(_ word: Kanji.Word) -> some View {
        VStack(spacing: DS.Spacing.xs) {
            HighlightedWord(word.text, highlighting: kanji?.character ?? "")
                .font(.dsWordLarge)
                .minimumScaleFactor(0.5)
            Text(verbatim: word.reading)
                .font(.dsReading)
                .foregroundStyle(.dsInkSecondary)
                .dsJapanese()
            Text(verbatim: word.shortMeaning)
                .font(.dsBody)
                .foregroundStyle(.dsInk)
        }
        .multilineTextAlignment(.center)
    }
}

#if DEBUG
#Preview("Notifica") {
    ReminderGlanceView(
        kanji: Kanji(
            character: "水",
            codepoint: "06c34",
            strokes: [
                "M52.77,15.08c1.08,1.08,1.67,2.49,1.76,5.52c0.4,14.55-0.26,62.16-0.26,67.12c0,9.78-7.52,0.03-9.02-1.22",
                "M17.5,45.75c1.75,0.62,3.73,0.43,5.25,0C25.88,44.88,36.09,41,38.59,40s4.47,1.24,3.75,3.5C39,54,28.25,69,19,74.75",
                "M81.22,27.5c-0.22,1.25-0.72,2.25-1.52,2.97c-5.64,5.1-12.45,9.78-22.45,13.78",
                "M57,46c8.82,10.73,19.23,21.46,28.42,27.42c2.16,1.4,4.52,3,7.08,3.58",
            ],
            onReadings: ["スイ"],
            kunReadings: ["みず"],
            meanings: ["water"]
        ),
        viewBox: 109
    )
}
#endif
