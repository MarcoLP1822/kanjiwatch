import SwiftUI

/// Namespace dei token che non hanno un tipo SwiftUI da estendere.
public enum DS {}

extension DS {
    /// Ritmo da 4 pt. Su un quadrante da 41 mm non serve altro.
    public enum Spacing {
        public static let xs: CGFloat = 2
        public static let s: CGFloat = 4
        public static let m: CGFloat = 8
        public static let l: CGFloat = 12
        public static let xl: CGFloat = 16
    }

    public enum Radius {
        public static let s: CGFloat = 6
        public static let m: CGFloat = 10
    }

    /// Token di componente per il glifo: valori legati al sistema di coordinate
    /// di KanjiVG, non a una dimensione in pixel.
    public enum Stroke {
        /// KanjiVG disegna con spessore 3 su 109. Un filo più spesso si legge meglio
        /// su uno schermo piccolo. È un rapporto: la larghezza si ricava dal lato.
        public static let widthRatio: CGFloat = 3.4 / 109
        /// Sagoma dei tratti non ancora disegnati.
        public static let guideOpacity: Double = 0.20
        /// Alone indaco dietro il glifo, il motivo della direzione visiva.
        public static let haloOpacity: Double = 0.16
        /// Lo spessore si calcola dal lato del riquadro: scalare la view con
        /// `scaleEffect` scalerebbe anche il tratto, e su 41 mm si vede. `ratio`
        /// permette tratti più spessi dove lo spazio è minuscolo, come sulle
        /// complication, senza duplicare cappucci e giunture.
        public static func style(forSide side: CGFloat, ratio: CGFloat = widthRatio) -> StrokeStyle {
            StrokeStyle(lineWidth: side * ratio, lineCap: .round, lineJoin: .round)
        }
    }
}
