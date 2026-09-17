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

    /// Token di componente per i bottoni.
    public enum Control {
        /// L'altezza dei bottoni di sistema su watchOS: sotto, il dito manca il bersaglio.
        public static let height: CGFloat = 44
        public static let borderWidth: CGFloat = 1.5
        public static let pressedOpacity: Double = 0.6
    }

    /// Token di componente per il tratto a pennello dei temi sumi-e.
    public nonisolated enum Brush {
        /// Spessore massimo, come frazione del lato: quasi il doppio della linea fine,
        /// perché il pennello si assottiglia e deve avere da dove partire.
        public static let widthRatio: CGFloat = 6.1 / 109
        /// Sagoma dei tratti non ancora scritti: un velo, non una traccia da ricalcare.
        public static let guideOpacity: Double = 0.07
        /// L'inchiostro che sbava nella carta: una copia più larga e trasparente sotto
        /// il tratto. Niente sfocatura, che sul Watch costerebbe a ogni fotogramma.
        public static let bleedScale: CGFloat = 1.3
        public static let bleedOpacity: Double = 0.12
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
