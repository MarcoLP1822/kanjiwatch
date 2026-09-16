import Foundation

/// La macchina a stati dei tap, senza SwiftUI e senza orologi.
///
///     glifo intero --tap--> disegno --fine--> attesa --> letture --tap--> glifo intero
///                              `--tap--> completo, e poi la stessa attesa
///
/// Un tap durante il disegno lo completa e basta: chi tocca due volte di fretta
/// non vuole saltare il contenuto, vuole vedere subito il kanji finito.
/// Lo stato non avvia timer né animazioni: dice alla view cosa fare con `Effect`.
public struct StudyState: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case glyph
        case readings
    }

    public let strokeCount: Int
    public private(set) var phase: Phase = .glyph
    /// Da 0 a `strokeCount`: la parte intera sono i tratti finiti, la decimale
    /// è quanto è disegnato quello in corso.
    public private(set) var progress: Double
    public private(set) var isDrawing = false

    public init(strokeCount: Int) {
        self.strokeCount = strokeCount
        // Si parte dal kanji intero: è quello che hai appena visto nella notifica.
        self.progress = Double(strokeCount)
    }

    public var isComplete: Bool { progress >= Double(strokeCount) }
}

extension StudyState {
    public enum Event: Equatable, Sendable {
        case tapped
        case crownMoved(to: Double)
        /// Il disegno è arrivato alla fine del tratto `to`.
        case drawingAdvanced(to: Double)
        case drawingFinished
        case holdElapsed
    }

    /// Cosa deve fare la view dopo l'evento.
    public enum Effect: Equatable, Sendable {
        case none
        case startDrawing
        case stopDrawing
        /// Tiene il glifo intero un istante, poi rimanda `holdElapsed`.
        case holdThenReveal
    }

    @discardableResult
    public mutating func handle(_ event: Event) -> Effect {
        switch event {
        case .tapped:
            return handleTap()

        case .crownMoved(let value):
            return scrub(to: value)

        case .drawingAdvanced(let value):
            // Se hai toccato o girato la corona, il disegno che continua ad arrivare
            // dal task non deve rimettere indietro le lancette.
            guard isDrawing else { return .none }
            progress = min(max(value, 0), Double(strokeCount))
            return .none

        case .drawingFinished:
            guard isDrawing else { return .none }
            isDrawing = false
            progress = Double(strokeCount)
            return .holdThenReveal

        case .holdElapsed:
            // Se nel frattempo hai toccato o girato la corona, l'attesa non vale più.
            guard phase == .glyph, !isDrawing, isComplete else { return .none }
            phase = .readings
            return .none
        }
    }

    private mutating func handleTap() -> Effect {
        switch (phase, isDrawing) {
        case (.readings, _):
            phase = .glyph
            progress = Double(strokeCount)
            return .none

        case (.glyph, true):
            // Salta alla fine; il passaggio alle letture resta quello normale.
            isDrawing = false
            progress = Double(strokeCount)
            return .holdThenReveal

        case (.glyph, false):
            progress = 0
            isDrawing = true
            return .startDrawing
        }
    }

    private mutating func scrub(to value: Double) -> Effect {
        // Fra le letture la corona scorre il testo, non i tratti.
        guard phase == .glyph else { return .none }
        let wasDrawing = isDrawing
        isDrawing = false
        progress = min(max(value, 0), Double(strokeCount))
        // Con la corona comandi tu: arrivare in fondo non rivela le letture.
        return wasDrawing ? .stopDrawing : .none
    }
}
