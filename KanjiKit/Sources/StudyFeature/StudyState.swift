import Foundation

/// La macchina a stati dei tocchi, senza SwiftUI e senza orologi.
///
///     kanji --tocco--> tratti --tocco--> letture  (poi DONE o NEXT)
///                        `--tocco durante il disegno: lo completa
///
/// Ogni passo è un tocco e niente avanza da solo. Nelle letture i tocchi non fanno
/// niente: lì decidono DONE e NEXT, che non sono affare di questa macchina ma del
/// loop nel dominio. Lo stato non avvia timer né animazioni: dice alla view cosa
/// fare con `Effect`.
public struct StudyState: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        /// Il kanji intero, com'era nella notifica.
        case kanji
        /// L'ordine dei tratti: in disegno, oppure fermo dove l'ha lasciato la corona.
        case strokes
        case readings
    }

    public let strokeCount: Int
    public private(set) var phase: Phase = .kanji
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
    }

    /// Cosa deve fare la view dopo l'evento.
    public enum Effect: Equatable, Sendable {
        case none
        case startDrawing
        case stopDrawing
    }

    @discardableResult
    public mutating func handle(_ event: Event) -> Effect {
        switch event {
        case .tapped:
            return handleTap()

        case .crownMoved(let value):
            // Fra le letture la corona scorre il testo, non i tratti.
            guard phase != .readings else { return .none }
            // Girare la corona è guardare i tratti a mano: il passo è fatto, e il
            // prossimo tocco porta alle letture invece di ridisegnare.
            phase = .strokes
            let wasDrawing = isDrawing
            isDrawing = false
            progress = clamped(value)
            return wasDrawing ? .stopDrawing : .none

        case .drawingAdvanced(let value):
            // Se hai toccato o girato la corona, il disegno che continua ad arrivare
            // dal task non deve rimettere indietro le lancette.
            guard isDrawing else { return .none }
            progress = clamped(value)
            return .none

        case .drawingFinished:
            guard isDrawing else { return .none }
            isDrawing = false
            progress = Double(strokeCount)
            return .none
        }
    }

    private mutating func handleTap() -> Effect {
        switch phase {
        case .kanji:
            phase = .strokes
            progress = 0
            isDrawing = true
            return .startDrawing

        case .strokes where isDrawing:
            // Chi tocca durante il disegno vuole il kanji finito, non saltare alle letture.
            isDrawing = false
            progress = Double(strokeCount)
            return .stopDrawing

        case .strokes:
            phase = .readings
            return .none

        case .readings:
            return .none
        }
    }

    private func clamped(_ value: Double) -> Double {
        min(max(value, 0), Double(strokeCount))
    }
}
