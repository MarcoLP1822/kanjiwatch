import SwiftUI

/// Livello 1 dei token: i valori grezzi. Non escono da questo modulo e non si usano
/// direttamente nelle view — per quello ci sono i token semantici in Colors.swift.
///
/// Direzione visiva "ai-zome": fondo notte, tratti bianco freddo, accento indaco.
/// I valori stanno in esadecimale (non in `Color`) così il test sul contrasto può
/// calcolare la luminanza senza disegnare niente.
enum Palette {
    /// Fondo: nero bluastro, non nero puro. Su OLED resta profondo ma non "buco".
    static let night: UInt32 = 0x05_070D
    /// Superficie sopra il fondo: card, riquadri, avvisi.
    static let nightRaised: UInt32 = 0x10_1A2E
    /// Tratti e testo primario.
    static let frost: UInt32 = 0xE8_EEF7
    /// Testo secondario: letture, didascalie.
    static let slate: UInt32 = 0x83_91A7
    /// Accento ai-iro. Contrasto 4.3:1 sul fondo: buono per forme e tratti,
    /// sotto soglia per il testo piccolo. Per quello c'è `indigoLight`.
    static let indigo: UInt32 = 0x3E_6FD8
    /// Variante chiara dell'accento, per il testo.
    static let indigoLight: UInt32 = 0x8F_AEF0
    /// Avvisi (permessi negati). Mai da solo: sempre con un'icona o un testo.
    static let amber: UInt32 = 0xE0_A23E
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
