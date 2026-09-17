import SwiftUI

/// Livello 2 dei token: colori per ruolo, non per valore. Le view usano solo questi, e
/// ognuno si risolve nel tema dell'ambiente: la stessa view è indaco su notte o
/// inchiostro su carta senza saperlo. Il prefisso `ds` li rende cercabili.
public nonisolated struct DSColor: ShapeStyle, Sendable {
    public enum Role: Sendable {
        case background, surface, ink, inkSecondary, accent, accentText, onAccent, warning
    }

    private let role: Role

    init(_ role: Role) {
        self.role = role
    }

    public func resolve(in environment: EnvironmentValues) -> Color.Resolved {
        environment.dsTheme.color(role).resolve(in: environment)
    }
}

extension ShapeStyle where Self == DSColor {
    /// Fondo di ogni schermata.
    public static var dsBackground: DSColor { DSColor(.background) }
    /// Superficie sopra il fondo: riquadri, avvisi.
    public static var dsSurface: DSColor { DSColor(.surface) }
    /// Testo primario e tratti già disegnati.
    public static var dsInk: DSColor { DSColor(.ink) }
    /// Testo secondario: letture, didascalie, etichette.
    public static var dsInkSecondary: DSColor { DSColor(.inkSecondary) }
    /// Accento per forme e tratti: il tratto in corso. Non per il testo piccolo.
    public static var dsAccent: DSColor { DSColor(.accent) }
    /// Accento per il testo: stessa famiglia, contrasto sufficiente.
    public static var dsAccentText: DSColor { DSColor(.accentText) }
    /// Testo sopra l'accento pieno.
    public static var dsOnAccent: DSColor { DSColor(.onAccent) }
    /// Avviso: permessi negati, stati che bloccano l'app.
    public static var dsWarning: DSColor { DSColor(.warning) }
}

nonisolated extension DSTheme {
    /// Il colore di un ruolo come `Color`, per le API che non accettano uno stile: i
    /// gradienti e gli `AttributedString`. Chi lo usa legge il tema dall'ambiente.
    public func color(_ role: DSColor.Role) -> Color {
        let value =
            switch role {
            case .background: palette.background
            case .surface: palette.surface
            case .ink: palette.ink
            case .inkSecondary: palette.inkSecondary
            case .accent: palette.accent
            case .accentText: palette.accentText
            case .onAccent: palette.onAccent
            case .warning: palette.warning
            }
        return Color(hex: value)
    }
}
