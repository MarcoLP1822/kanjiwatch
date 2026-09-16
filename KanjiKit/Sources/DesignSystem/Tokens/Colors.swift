import SwiftUI

/// Livello 2 dei token: colori per ruolo, non per valore. Le view usano solo questi.
/// Il prefisso `ds` li rende cercabili e non litiga con i colori di sistema.
extension Color {
    /// Fondo di ogni schermata.
    public static let dsBackground = Color(hex: Palette.night)
    /// Superficie sopra il fondo: riquadri, avvisi.
    public static let dsSurface = Color(hex: Palette.nightRaised)
    /// Testo primario e tratti già disegnati.
    public static let dsInk = Color(hex: Palette.frost)
    /// Testo secondario: letture, didascalie, etichette.
    public static let dsInkSecondary = Color(hex: Palette.slate)
    /// Accento per forme e tratti: il tratto in corso. Non per il testo piccolo.
    public static let dsAccent = Color(hex: Palette.indigo)
    /// Accento per il testo: stessa famiglia, contrasto sufficiente.
    public static let dsAccentText = Color(hex: Palette.indigoLight)
    /// Avviso: permessi negati, stati che bloccano l'app.
    public static let dsWarning = Color(hex: Palette.amber)
}

extension ShapeStyle where Self == Color {
    public static var dsBackground: Color { .dsBackground }
    public static var dsSurface: Color { .dsSurface }
    public static var dsInk: Color { .dsInk }
    public static var dsInkSecondary: Color { .dsInkSecondary }
    public static var dsAccent: Color { .dsAccent }
    public static var dsAccentText: Color { .dsAccentText }
    public static var dsWarning: Color { .dsWarning }
}
