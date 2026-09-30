import DesignSystem
import KanjiDomain
import SwiftUI

/// La schermata di ripasso: il kanji, i tratti, le letture; poi l'attesa del prossimo.
///
/// Il tocco sul glifo è un `Button` con lo stile `dsTapArea`: la semantica del bottone
/// per VoiceOver, senza lo sfondo di sistema che si mangerebbe il quadrante.
public struct StudyView: View {
    private let model: StudyViewModel
    @State private var crown: Double = 0
    @Environment(\.dsTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(model: StudyViewModel) {
        self.model = model
    }

    public var body: some View {
        ZStack {
            Rectangle().fill(.dsBackground).ignoresSafeArea()
            DSTopWash()

            Group {
                if model.snapshot.isDone {
                    waiting
                } else if model.state.phase == .readings {
                    readings
                } else {
                    glyph
                }
            }
            // Sfuma solo la schermata che entra: quella che esce sparisce subito. In una
            // dissolvenza incrociata le due convivono per un attimo, e watchOS toglieva
            // la corona anche alla nuova: le letture non scorrevano finché non toccavi.
            .transition(.asymmetric(insertion: .opacity, removal: .identity))
        }
        // Con "Riduci movimento" i cambi di passo avvengono senza movimento. Le dissolvenze
        // restano: non spostano niente sullo schermo.
        .animation(reduceMotion ? nil : DS.Motion.phase, value: model.state.phase)
        .animation(reduceMotion ? nil : DS.Motion.phase, value: model.snapshot.isDone)
        .onChange(of: reduceMotion, initial: true) { _, reduce in model.reducesMotion = reduce }
        .onAppear { crown = model.state.progress }
        .onChange(of: model.snapshot.startedAt) { _, _ in crown = model.state.progress }
    }

    // MARK: - Kanji e tratti

    /// Un bottone vero con lo stile dell'area da toccare: VoiceOver lo annuncia col kanji
    /// e il suo significato, e lo attiva come ogni bottone. La corona sta sul contenitore,
    /// fuori dal bottone, così il fuoco della corona non cambia il suo comportamento.
    private var glyph: some View {
        ZStack {
            Button {
                model.send(.tapped)
            } label: {
                glyphContent
            }
            .buttonStyle(.dsTapArea)
            .accessibilityLabel(
                Text("Kanji \(model.kanji.character), meaning \(model.kanji.shortMeaning)", bundle: .module)
            )
            .accessibilityHint(hint ?? Text(verbatim: ""))
        }
        .dsCrownScrubbing($crown, upTo: Double(model.state.strokeCount))
        .onChange(of: crown) { _, turned in
            // La corona vale solo quando la muovi tu: quando è il disegno a far
            // avanzare il progresso, il valore della corona resta dov'è.
            if abs(turned - model.state.progress) > 0.01 {
                model.send(.crownMoved(to: turned))
            }
        }
    }

    private var glyphContent: some View {
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
                // La parola della notifica che ti ha portato qui, non sempre la più
                // comune: se al polso hai visto 水道, qui ritrovi 水道.
                word: model.kanji.word(for: model.snapshot.reference),
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
                missed: model.missedKanji,
                missedEvery: model.missed.every,
                onNext: model.next,
                onReviewMissed: model.reviewMissed,
                onScheduleMissed: model.scheduleMissed
            )
            // Niente margine in alto: sotto la barra c'è già spazio, e così "Un altro
            // adesso" sale senza rimpicciolire niente.
            .padding([.horizontal, .bottom], DS.Spacing.m)
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
    var word: Kanji.Word?
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

            if let word = word ?? kanji.commonWord {
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

                if dailyLimitReached {
                    Text("That's all for today", bundle: .module)
                        .font(.dsLabel)
                        .foregroundStyle(.dsInkSecondary)
                        .frame(maxWidth: .infinity)
                } else {
                    OneMoreButton(action: onNext)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Dopo DONE: il kanji appena fatto in piccolo, poi che per ora è tutto e quando arriva
/// il prossimo. Prima di tutto va detto che hai finito e puoi abbassare il polso; NEXT,
/// se la giornata lo permette, sta in fondo per chi non vuole aspettare.
struct WaitingContent: View {
    let kanji: Kanji
    let glyph: StrokeGlyph?
    let nextArrival: Date?
    let dailyLimitReached: Bool
    /// A giornata finita, i kanji di oggi che non hai aperto; vuoto altrimenti.
    var missed: [Kanji] = []
    /// Ogni quanti minuti si possono rimandare; nil se oggi non c'è più posto.
    var missedEvery: Int? = nil
    let onNext: () -> Void
    var onReviewMissed: () -> Void = {}
    var onScheduleMissed: () -> Void = {}

    var body: some View {
        VStack(spacing: DS.Spacing.m) {
            // Kanji e significato su una riga, come in testa alle letture: in colonna
            // mangiavano lo spazio, e "Un altro adesso" finiva sotto il bordo.
            HStack(spacing: DS.Spacing.m) {
                if let glyph {
                    KanjiGlyphView(glyph: glyph, progress: Double(glyph.strokeCount))
                        .frame(width: 44, height: 44)
                }
                Text(verbatim: kanji.shortMeaning)
                    .font(.dsBody)
                    .foregroundStyle(.dsInkSecondary)
                    .lineLimit(2)
            }

            VStack(spacing: DS.Spacing.s) {
                headline
                    .font(.dsTitle)
                    .foregroundStyle(.dsInk)
                arrival
                    .font(.dsBody)
                    .foregroundStyle(.dsInkSecondary)
                if dailyLimitReached, missed.isEmpty {
                    // Solo senza Premium: col Premium NEXT va oltre il limite, e qui
                    // resta il bottone. Coi kanji saltati da mostrare, conta di più quello.
                    Text("With Premium you can keep going whenever you like: find it in Settings.", bundle: .module)
                        .font(.dsLabel)
                        .foregroundStyle(.dsInkSecondary)
                }
            }
            .multilineTextAlignment(.center)

            if !missed.isEmpty {
                missedPanel
            }

            if !dailyLimitReached {
                OneMoreButton(action: onNext)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Proposta dall'utente: a giornata finita, quanti ne hai saltati e se vuoi
    /// vederli ora o farteli rimandare. Non passano dal tetto del giorno: sono kanji che
    /// la giornata aveva già avuto.
    private var missedPanel: some View {
        VStack(spacing: DS.Spacing.s) {
            Text("You skipped \(missed.count) kanji today. Want to see them now?", bundle: .module)
                .font(.dsBody)
                .foregroundStyle(.dsInk)
                .multilineTextAlignment(.center)
            Text(verbatim: missed.prefix(8).map(\.character).joined(separator: " "))
                .font(.system(size: 24))
                .foregroundStyle(.dsInkSecondary)
                .dsJapanese()
                .accessibilityHidden(true)
            Button(action: onReviewMissed) {
                Text("Now", bundle: .module)
            }
            .buttonStyle(.dsPrimary)
            if let missedEvery {
                Button(action: onScheduleMissed) {
                    if missed.count == 1 {
                        Text("Schedule it in \(missedEvery) min", bundle: .module)
                    } else {
                        Text("Schedule every \(missedEvery) min", bundle: .module)
                    }
                }
                .buttonStyle(.dsSecondary)
            } else {
                // Fuori dalla fascia oraria non si rimanda niente: il Watch non suona di
                // notte. Detto, invece di far sparire il bottone senza spiegazioni.
                Group {
                    if missed.count == 1 {
                        Text("Too late to schedule it today: it'll come back on its own.", bundle: .module)
                    } else {
                        Text("Too late to schedule them today: they'll come back on their own.", bundle: .module)
                    }
                }
                    .font(.dsLabel)
                    .foregroundStyle(.dsInkSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    /// "Per oggi" solo quando fino a domani non arriva più niente, anche col Premium; se
    /// arriva ancora qualcosa oggi — magari un kanji saltato, rimandato — è "per ora".
    private var headline: Text {
        let dayIsOver = nextArrival.map { !Calendar.current.isDateInToday($0) } ?? dailyLimitReached
        return dayIsOver
            ? Text("That's all for today", bundle: .module)
            : Text("That's all for now", bundle: .module)
    }

    /// L'ora basta: la prossima notifica arriva al più tardi domani, all'inizio della
    /// fascia attiva.
    private var arrival: Text {
        guard let nextArrival else {
            return Text("Notifications are off", bundle: .module)
        }
        let time = nextArrival.formatted(date: .omitted, time: .shortened)
        return Calendar.current.isDateInToday(nextArrival)
            ? Text("Next at \(time)", bundle: .module)
            : Text("Next tomorrow at \(time)", bundle: .module)
    }
}

/// NEXT: un altro kanji subito, senza aspettare la notifica. Si chiamava "Avanti", e
/// dopo DONE sembrava il modo di proseguire: chi aveva finito non sapeva se premerlo.
private struct OneMoreButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("One more now", bundle: .module)
        }
        .buttonStyle(.dsSecondary)
    }
}
