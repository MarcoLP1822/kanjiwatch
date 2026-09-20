import DesignSystem
import Foundation
import KanjiDomain
import Observation
import SwiftUI

/// Tiene insieme il kanji in gioco, i suoi tratti già interpretati e la macchina a
/// stati. Qui stanno i tempi — il task del disegno e l'attesa della prossima
/// notifica — perché la logica in `StudyState` e `StudyLoop` deve restare provabile
/// senza far girare un orologio.
@Observable
public final class StudyViewModel {
    /// Il kanji in gioco, se il suo giro è chiuso e quando arriva il prossimo.
    public private(set) var snapshot: StudyLoop.Snapshot
    /// Nil solo se i tracciati fossero illeggibili: la view mostra il carattere
    /// come testo invece di una schermata vuota.
    public private(set) var glyph: StrokeGlyph?
    public private(set) var state: StudyState

    private var loop: StudyLoop
    @ObservationIgnored private var drawing: Task<Void, Never>?

    /// NEXT ha messo in gioco un altro kanji: la coda delle notifiche va rifatta da adesso.
    @ObservationIgnored public var onAdvance: (() -> Void)?
    /// Scatta la prima volta che arrivi alle letture. Serve a chiedere il permesso
    /// notifiche quando l'utente ha già capito cosa fa l'app, invece che al primo
    /// avvio davanti a una schermata che non gli dice niente.
    @ObservationIgnored public var onReadingsFirstShown: (() -> Void)?
    @ObservationIgnored private var hasShownReadings = false

    /// "Riduci movimento": i tratti compaiono interi, uno alla volta, con le stesse pause.
    /// L'ordine resta leggibile, che è lo scopo, senza niente che scorra sullo schermo.
    @ObservationIgnored public var reducesMotion = false

    public init(loop: StudyLoop) {
        guard let snapshot = loop.current() else {
            preconditionFailure("il mazzo nel bundle non può essere vuoto")
        }
        self.loop = loop
        self.snapshot = snapshot
        glyph = try? StrokeGlyph(kanji: snapshot.current, viewBox: loop.deck.viewBox)
        state = StudyState(strokeCount: snapshot.current.strokeCount)
    }

    // Niente deinit: il task tiene `self` debole e finisce da solo in pochi secondi.
    // Un deinit isolato al MainActor, qui, costerebbe più di quanto vale.

    public var kanji: Kanji { snapshot.current }

    public func send(_ event: StudyState.Event) {
        let previous = state.phase
        perform(state.handle(event))
        guard previous != .readings, state.phase == .readings else { return }

        // Ogni volta che arrivi in fondo a un kanji, non solo la prima: è così che
        // l'app capisce quali kanji ti interessano, senza chiedertelo.
        loop.readingsViewed(kanji.codepoint)
        if !hasShownReadings {
            hasShownReadings = true
            onReadingsFirstShown?()
        }
    }

    public func done() {
        apply(loop.done(kanji.codepoint))
    }

    public func next() {
        let previousTurn = snapshot.startedAt
        apply(loop.next(after: kanji.codepoint))
        if snapshot.startedAt != previousTurn {
            onAdvance?()
        }
    }

    /// Dalla notifica o dalla complication: il kanji che hai guardato al polso, da capo.
    public func open(codepoint: String) {
        apply(loop.open(codepoint: codepoint))
    }

    /// Al ritorno in primo piano e dopo ogni rischedulazione: una notifica arrivata
    /// nel frattempo mette in gioco il suo kanji, e l'orario del prossimo può essere
    /// cambiato.
    public func refresh() {
        apply(loop.current())
    }

    /// Sono cambiati i mazzi attivi. Se il kanji in gioco c'è ancora si resta lì:
    /// toglierti da sotto le dita quello che stai guardando è peggio che ricominciare.
    public func replace(loop: StudyLoop) {
        self.loop = loop
        refresh()
    }

    /// Sulla schermata d'attesa: all'ora della prossima notifica il suo kanji
    /// compare da solo, senza lasciare a schermo un orario già passato.
    public func waitForNextArrival() async {
        guard snapshot.isDone, let arrival = snapshot.nextArrival else { return }
        // Un secondo di margine: svegliarsi un soffio prima dell'orario lascerebbe la
        // notifica non ancora arrivata, e l'attesa ferma lì.
        try? await Task.sleep(for: .seconds(max(arrival.timeIntervalSinceNow, 0) + 1))
        guard !Task.isCancelled else { return }
        refresh()
    }

    // MARK: - Effetti

    /// Un turno nuovo riparte dal kanji intero; lo stesso turno resta dov'è, anche
    /// se nel frattempo è cambiato l'orario della prossima notifica.
    private func apply(_ new: StudyLoop.Snapshot?) {
        guard let new else { return }
        let isNewTurn = new.startedAt != snapshot.startedAt || new.current != snapshot.current
        snapshot = new
        guard isNewTurn else { return }
        drawing?.cancel()
        glyph = try? StrokeGlyph(kanji: new.current, viewBox: loop.deck.viewBox)
        state = StudyState(strokeCount: new.current.strokeCount)
    }

    private func perform(_ effect: StudyState.Effect) {
        switch effect {
        case .none:
            break
        case .startDrawing:
            startDrawing()
        case .stopDrawing:
            drawing?.cancel()
            drawing = nil
        }
    }

    /// Un tratto per volta, con durata proporzionale alla lunghezza. L'interpolazione
    /// la fa SwiftUI: `KanjiGlyphView` è `Animatable`, quindi basta spostare il
    /// progresso dentro `withAnimation` e aspettare.
    private func startDrawing() {
        drawing?.cancel()
        guard let glyph else {
            send(.drawingFinished)
            return
        }
        drawing = Task { [weak self] in
            for (position, duration) in glyph.durations.enumerated() {
                guard !Task.isCancelled else { return }
                if self?.reducesMotion == true {
                    self?.send(.drawingAdvanced(to: Double(position + 1)))
                } else {
                    withAnimation(.linear(duration: duration)) {
                        self?.send(.drawingAdvanced(to: Double(position + 1)))
                    }
                }
                try? await Task.sleep(for: .seconds(duration + DS.Motion.strokePause))
            }
            guard !Task.isCancelled else { return }
            self?.send(.drawingFinished)
        }
    }
}
