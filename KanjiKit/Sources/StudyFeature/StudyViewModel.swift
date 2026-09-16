import DesignSystem
import Foundation
import KanjiDomain
import Observation
import SwiftUI

/// Tiene insieme il kanji corrente, i suoi tratti già interpretati e la macchina
/// a stati. Qui stanno i tempi — i task del disegno e dell'attesa — perché la
/// logica in `StudyState` deve restare provabile senza far girare un orologio.
@Observable
public final class StudyViewModel {
    public private(set) var kanji: Kanji
    /// Nil solo se i tracciati fossero illeggibili: la view mostra il carattere
    /// come testo invece di una schermata vuota.
    public private(set) var glyph: StrokeGlyph?
    public private(set) var state: StudyState

    private let queue: [Kanji]
    private let viewBox: Double
    private var index: Int
    @ObservationIgnored private var drawing: Task<Void, Never>?
    @ObservationIgnored private var hold: Task<Void, Never>?

    /// Scatta la prima volta che un'animazione arriva in fondo. Serve a chiedere
    /// il permesso notifiche quando l'utente ha già capito cosa fa l'app, invece
    /// che al primo avvio davanti a una schermata che non gli dice niente.
    @ObservationIgnored public var onFirstDrawingCompleted: (() -> Void)?
    @ObservationIgnored private var hasCompletedADrawing = false

    public init(deck: KanjiDeck, startAt codepoint: String? = nil) {
        precondition(!deck.isEmpty, "il mazzo nel bundle non può essere vuoto")
        let cards = deck.kanji
        let start = codepoint.flatMap { wanted in cards.firstIndex { $0.codepoint == wanted } } ?? 0
        queue = cards
        viewBox = deck.viewBox
        index = start
        kanji = cards[start]
        glyph = try? StrokeGlyph(svgPaths: cards[start].strokes, viewBox: deck.viewBox)
        state = StudyState(strokeCount: cards[start].strokeCount)
    }

    // Niente deinit: i task tengono `self` debole e finiscono da soli in meno di
    // un secondo. Un deinit isolato al MainActor, qui, costerebbe più di quanto vale.

    public func send(_ event: StudyState.Event) {
        perform(state.handle(event))
    }

    /// Dalla notifica: apre direttamente sul kanji che hai guardato al polso.
    public func show(codepoint: String) {
        guard let position = queue.firstIndex(where: { $0.codepoint == codepoint }) else { return }
        show(at: position)
    }

    public func showNext() {
        show(at: (index + 1) % queue.count)
    }

    public func showPrevious() {
        show(at: (index - 1 + queue.count) % queue.count)
    }

    // MARK: - Effetti

    private func perform(_ effect: StudyState.Effect) {
        switch effect {
        case .none:
            break
        case .startDrawing:
            startDrawing()
        case .stopDrawing:
            drawing?.cancel()
            drawing = nil
        case .holdThenReveal:
            holdThenReveal()
        }
    }

    /// Un tratto per volta, con durata proporzionale alla lunghezza. L'interpolazione
    /// la fa SwiftUI: `KanjiGlyphView` è `Animatable`, quindi basta spostare il
    /// progresso dentro `withAnimation` e aspettare.
    private func startDrawing() {
        drawing?.cancel()
        hold?.cancel()
        guard let glyph else {
            send(.drawingFinished)
            return
        }
        drawing = Task { [weak self] in
            for (position, duration) in glyph.durations.enumerated() {
                guard !Task.isCancelled else { return }
                withAnimation(.linear(duration: duration)) {
                    self?.send(.drawingAdvanced(to: Double(position + 1)))
                }
                try? await Task.sleep(for: .seconds(duration + DS.Motion.strokePause))
            }
            guard !Task.isCancelled else { return }
            self?.send(.drawingFinished)
        }
    }

    private func holdThenReveal() {
        drawing?.cancel()
        hold?.cancel()
        if !hasCompletedADrawing {
            hasCompletedADrawing = true
            onFirstDrawingCompleted?()
        }
        hold = Task { [weak self] in
            try? await Task.sleep(for: .seconds(DS.Motion.completionHold))
            guard !Task.isCancelled else { return }
            self?.send(.holdElapsed)
        }
    }

    private func show(at position: Int) {
        drawing?.cancel()
        hold?.cancel()
        index = position
        kanji = queue[position]
        glyph = try? StrokeGlyph(svgPaths: kanji.strokes, viewBox: viewBox)
        state = StudyState(strokeCount: kanji.strokeCount)
    }
}
