import SwiftUI

extension View {
    /// Lega la corona digitale allo scorrimento dei tratti.
    ///
    /// È la cosa che rende l'app tua e non un esercizio da tutorial: i tratti si
    /// tirano avanti e indietro a mano. Fuori da watchOS non fa niente, così le
    /// preview e i test su Mac compilano lo stesso.
    public func dsCrownScrubbing(_ value: Binding<Double>, upTo maximum: Double) -> some View {
        #if os(watchOS)
        return focusable()
            .digitalCrownRotation(
                value,
                from: 0,
                through: maximum,
                by: 0.25,
                sensitivity: .medium,
                isContinuous: false,
                isHapticFeedbackEnabled: true
            )
        #else
        return self
        #endif
    }
}
