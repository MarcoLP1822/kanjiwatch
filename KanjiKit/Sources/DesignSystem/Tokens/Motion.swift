import SwiftUI

extension DS {
    /// Tempi dell'animazione. La durata di un tratto dipende dalla sua lunghezza:
    /// a durata fissa, un tratto lungo sembra scattare e uno corto strisciare.
    public enum Motion {
        /// Unità del viewBox (109 di lato) al secondo.
        public static let strokeSpeed: Double = 170
        /// Sotto questa soglia il tratto diventa un lampo, sopra si aspetta troppo.
        public static let strokeDurationRange: ClosedRange<Double> = 0.18...0.9
        /// Respiro tra un tratto e il successivo: senza, l'ordine non si legge.
        public static let strokePause: Double = 0.07
        /// Quanto resta fermo il glifo completo prima di passare alle letture.
        public static let completionHold: Double = 0.55
        /// Cambio di fase (glifo → letture).
        public static let phase: Animation = .smooth(duration: 0.28)

        public static func strokeDuration(forLength length: Double) -> Double {
            min(max(length / strokeSpeed, strokeDurationRange.lowerBound), strokeDurationRange.upperBound)
        }
    }
}
