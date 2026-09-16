import DesignSystem
import KanjiDomain
import SwiftUI

/// La schermata di ripasso: il glifo, poi le letture.
///
/// Il tocco sta su una `ZStack` e non su un `Button` di proposito: su watchOS il
/// bottone impone lo stile di sistema e si mangia l'area utile del quadrante.
public struct StudyView: View {
    private let model: StudyViewModel
    @State private var crown: Double = 0

    public init(model: StudyViewModel) {
        self.model = model
    }

    public var body: some View {
        ZStack {
            Color.dsBackground.ignoresSafeArea()

            switch model.state.phase {
            case .glyph:
                glyph
            case .readings:
                readings
            }
        }
        .animation(DS.Motion.phase, value: model.state.phase)
        .onAppear { crown = model.state.progress }
    }

    // MARK: - Glifo

    private var glyph: some View {
        VStack(spacing: DS.Spacing.s) {
            drawing
                .frame(maxHeight: .infinity)

            if !model.state.isDrawing, model.state.isComplete {
                Text("Tap for stroke order", bundle: .module)
                    .font(.dsLabel)
                    .foregroundStyle(.dsInkSecondary)
                    .transition(.opacity)
            }
        }
        .padding(DS.Spacing.m)
        .contentShape(.rect)
        .onTapGesture { model.send(.tapped) }
        .dsCrownScrubbing($crown, upTo: Double(model.state.strokeCount))
        .onChange(of: crown) { _, turned in
            // La corona vale solo quando la muovi tu: quando è il disegno a far
            // avanzare il progresso, il valore della corona resta dov'è.
            if abs(turned - model.state.progress) > 0.01 {
                model.send(.crownMoved(to: turned))
            }
        }
        .onChange(of: model.kanji.codepoint) { _, _ in crown = model.state.progress }
        .gesture(
            // Scorciatoia per il ripasso attivo: su per il prossimo, giù per tornare.
            DragGesture(minimumDistance: 24)
                .onEnded { drag in
                    if drag.translation.height < -24 {
                        model.showNext()
                    } else if drag.translation.height > 24 {
                        model.showPrevious()
                    }
                }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Kanji \(model.kanji.character), meaning \(meanings)", bundle: .module))
        .accessibilityHint(Text("Tap for stroke order", bundle: .module))
    }

    @ViewBuilder
    private var drawing: some View {
        if let glyph = model.glyph {
            KanjiGlyphView(glyph: glyph, progress: model.state.progress)
        } else {
            // Tracciati illeggibili: meglio il carattere che una schermata vuota.
            Text(verbatim: model.kanji.character)
                .font(.system(size: 72))
                .foregroundStyle(.dsInk)
                .dsJapanese()
        }
    }

    // MARK: - Letture

    private var readings: some View {
        ScrollView {
            ReadingsContent(kanji: model.kanji, glyph: model.glyph, onNext: model.showNext)
                .padding(DS.Spacing.m)
        }
        .contentShape(.rect)
        .onTapGesture { model.send(.tapped) }
    }

    private var meanings: String {
        model.kanji.meanings.prefix(2).joined(separator: ", ")
    }
}

/// Il contenuto delle letture, staccato dalla `ScrollView`.
///
/// Serve anche a poterlo guardare: dentro una `ScrollView`, `ImageRenderer`
/// restituisce un'immagine vuota, quindi il test renderizza direttamente questo.
struct ReadingsContent: View {
    let kanji: Kanji
    let glyph: StrokeGlyph?
    let onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            HStack(alignment: .center, spacing: DS.Spacing.m) {
                if let glyph {
                    KanjiGlyphView(glyph: glyph, progress: Double(glyph.strokeCount))
                        .frame(width: 44, height: 44)
                }
                Text(verbatim: meanings)
                    .font(.dsTitle)
                    .foregroundStyle(.dsInk)
            }

            ReadingRow(label: "on", readings: kanji.onReadings)
            ReadingRow(label: "kun", readings: kanji.kunReadings)

            if let word = kanji.commonWord {
                WordCard(
                    word: word.text,
                    highlighting: kanji.character,
                    reading: word.reading,
                    meaning: word.meanings.prefix(2).joined(separator: ", ")
                )
            }

            Button(action: onNext) {
                Text("Next kanji", bundle: .module)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.dsAccent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var meanings: String {
        kanji.meanings.prefix(2).joined(separator: ", ")
    }
}
