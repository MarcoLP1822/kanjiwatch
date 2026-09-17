import SwiftUI

extension DS {
    /// Tempi dell'animazione. La durata di un tratto dipende dalla sua lunghezza:
    /// a durata fissa, un tratto lungo sembra scattare e uno corto strisciare.
    public enum Motion {
        /// Unità del viewBox (109 di lato) al secondo: circa il passo di una mano che
        /// scrive. A 170, con le soglie di prima, passavano tre tratti al secondo.
        public static let strokeSpeed: Double = 110
        /// Metà dei tratti dei jōyō è più corta di 34 unità: senza un minimo leggibile,
        /// puntini e trattini passano come lampi. Sopra il massimo si aspetta troppo.
        public static let strokeDurationRange: ClosedRange<Double> = 0.3...1.1
        /// Respiro tra un tratto e il successivo: deve separarli a colpo d'occhio,
        /// altrimenti si vede il kanji comparire e non l'ordine dei tratti.
        public static let strokePause: Double = 0.2
        /// Cambio di fase (glifo → letture).
        public static let phase: Animation = .smooth(duration: 0.28)

        public static func strokeDuration(forLength length: Double) -> Double {
            min(max(length / strokeSpeed, strokeDurationRange.lowerBound), strokeDurationRange.upperBound)
        }
    }
}
