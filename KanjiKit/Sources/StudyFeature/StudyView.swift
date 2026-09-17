import DesignSystem
import KanjiDomain
import SwiftUI

/// La schermata di ripasso: il kanji, i tratti, le letture; poi l'attesa del prossimo.
///
/// Il tocco sul glifo sta su una `ZStack` e non su un `Button` di proposito: su
/// watchOS il bottone impone lo stile di sistema e si mangia l'area utile del quadrante.
public struct StudyView: View {
    private let model: StudyViewModel
    @State private var crown: Double = 0
    @Environment(\.dsTheme) private var theme

    public init(model: StudyViewModel) {
        self.model = model
    }

    public var body: some View {
        ZStack {
            Rectangle().fill(.dsBackground).ignoresSafeArea()
            DSTopWash()

            if model.snapshot.isDone {
                waiting
            } else if model.state.phase == .readings {
                readings
            } else {
                glyph
            }
        }
        .animation(DS.Motion.phase, value: model.state.phase)
        .animation(DS.Motion.phase, value: model.snapshot.isDone)
        .onAppear { crown = model.state.progress }
        .onChange(of: model.snapshot.startedAt) { _, _ in crown = model.state.progress }
    }

    // MARK: - Kanji e tratti

    private var glyph: some View {
        VStack(spacing: DS.Spacing.s) {
            drawing
                .frame(maxHeight: .infinity)
                .overlay(alignment: .topTrailing) {
                    if theme.showsSeal {
                        // Appena fuori dal riquadro del glifo: molti kanji arrivano fino
                        // all'angolo, e il sigillo non deve coprire un tratto.
                        KanjiSeal(strokeCount: model.state.strokeCount)
                            .offset(x: DS.Spacing.l, y: -DS.Spacing.s)
                    }
                }

            if let hint {
                hint
                    .font(.dsLabel)
                    .foregroundStyle(.dsInkSecondary)
                    .multilineTextAlignment(.center)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text("Kanji \(model.kanji.character), meaning \(model.kanji.shortMeaning)", bundle: .module)
        )
        .accessibilityHint(hint ?? Text(verbatim: ""))
        .accessibilityAddTraits(.isButton)
    }

    /// Cosa fa il prossimo tocco. Durante il disegno niente scritta: il tocco lo
    /// completa soltanto, e dirlo sarebbe rumore.
    private var hint: Text? {
        switch model.state.phase {
        case .kanji:
            Text("Tap for stroke order", bundle: .module)
        case .strokes where !model.state.isDrawing:
            Text("Tap for readings", bundle: .module)
        case .strokes, .readings:
            nil
        }
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

    // MARK: - Letture e attesa

    /// Qui i tocchi non fanno niente: si esce solo con DONE o NEXT.
    private var readings: some View {
        ScrollView {
            ReadingsContent(
                kanji: model.kanji,
                glyph: model.glyph,
                dailyLimitReached: model.snapshot.dailyLimitReached,
                onDone: model.done,
                onNext: model.next
            )
            .padding(DS.Spacing.m)
        }
    }

    private var waiting: some View {
        ScrollView {
            WaitingContent(
                kanji: model.kanji,
                glyph: model.glyph,
                nextArrival: model.snapshot.nextArrival,
                dailyLimitReached: model.snapshot.dailyLimitReached,
                onNext: model.next
            )
            .padding(DS.Spacing.m)
        }
        .task(id: model.snapshot.nextArrival) { await model.waitForNextArrival() }
    }
}

/// Il contenuto delle letture, staccato dalla `ScrollView`.
///
/// Serve anche a poterlo guardare: dentro una `ScrollView`, `ImageRenderer`
/// restituisce un'immagine vuota, quindi il test renderizza direttamente questo.
struct ReadingsContent: View {
    let kanji: Kanji
    let glyph: StrokeGlyph?
    let dailyLimitReached: Bool
    let onDone: () -> Void
    let onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            HStack(alignment: .center, spacing: DS.Spacing.m) {
                if let glyph {
                    KanjiGlyphView(glyph: glyph, progress: Double(glyph.strokeCount))
                        .frame(width: 44, height: 44)
                }
                Text(verbatim: kanji.shortMeaning)
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
                    meaning: word.shortMeaning
                )
            }

            VStack(spacing: DS.Spacing.m) {
                // DONE è il gesto normale e sta in evidenza; NEXT è per chi ne vuole un altro subito.
                Button(action: onDone) {
                    Text("Done", bundle: .module)
                }
                .buttonStyle(.dsPrimary)

                NextAction(dailyLimitReached: dailyLimitReached, action: onNext)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Dopo DONE: il kanji appena fatto in piccolo, quando arriva il prossimo e, se la
/// giornata lo permette, NEXT per non aspettare.
struct WaitingContent: View {
    let kanji: Kanji
    let glyph: StrokeGlyph?
    let nextArrival: Date?
    let dailyLimitReached: Bool
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: DS.Spacing.l) {
            VStack(spacing: DS.Spacing.s) {
                if let glyph {
                    KanjiGlyphView(glyph: glyph, progress: Double(glyph.strokeCount))
                        .frame(width: 56, height: 56)
                }
                Text(verbatim: kanji.shortMeaning)
                    .font(.dsLabel)
                    .foregroundStyle(.dsInkSecondary)
            }

            arrival
                .font(.dsBody)
                .foregroundStyle(.dsInk)
                .multilineTextAlignment(.center)

            NextAction(dailyLimitReached: dailyLimitReached, action: onNext)
        }
        .frame(maxWidth: .infinity)
    }

    /// L'ora basta: la prossima notifica arriva al più tardi domani, all'inizio della
    /// fascia attiva.
    private var arrival: Text {
        guard let nextArrival else {
            return Text("Notifications are off", bundle: .module)
        }
        let time = nextArrival.formatted(date: .omitted, time: .shortened)
        return Calendar.current.isDateInToday(nextArrival)
            ? Text("Next kanji at \(time)", bundle: .module)
            : Text("Next kanji tomorrow at \(time)", bundle: .module)
    }
}

/// NEXT, o il motivo per cui non c'è.
private struct NextAction: View {
    let dailyLimitReached: Bool
    let action: () -> Void

    var body: some View {
        if dailyLimitReached {
            Text("That's all for today", bundle: .module)
                .font(.dsLabel)
                .foregroundStyle(.dsInkSecondary)
                .frame(maxWidth: .infinity)
        } else {
            Button(action: action) {
                Text("Next", bundle: .module)
            }
            .buttonStyle(.dsSecondary)
        }
    }
}
