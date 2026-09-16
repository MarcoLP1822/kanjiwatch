import Foundation
import Testing

@testable import DesignSystem

/// Il contrasto è una proprietà dei token, non della singola schermata: se qualcuno
/// ritocca la palette, questi test cadono prima che l'app diventi illeggibile al sole.
@Suite("Contrasto dei token")
struct TokenContrastTests {
    /// Luminanza relativa secondo WCAG 2.1, da un colore sRGB a 8 bit.
    private func luminance(_ hex: UInt32) -> Double {
        let channels = [16, 8, 0].map { shift -> Double in
            let value = Double((hex >> UInt32(shift)) & 0xFF) / 255
            return value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
    }

    private func contrast(_ first: UInt32, _ second: UInt32) -> Double {
        let luminances = [luminance(first), luminance(second)]
        return (luminances.max()! + 0.05) / (luminances.min()! + 0.05)
    }

    @Test func everyTextTokenClearsTheWcagThreshold() {
        #expect(contrast(Palette.frost, Palette.night) >= 4.5)
        #expect(contrast(Palette.slate, Palette.night) >= 4.5)
        #expect(contrast(Palette.indigoLight, Palette.night) >= 4.5)
        #expect(contrast(Palette.amber, Palette.night) >= 4.5)
    }

    /// Il motivo per cui esistono due indaco: quello pieno è per i tratti, non per
    /// il testo piccolo. Se un giorno passasse la soglia, tanto meglio saperlo.
    @Test func fullAccentIsForGraphicsOnly() {
        let accent = contrast(Palette.indigo, Palette.night)
        #expect(accent >= 3.0)
        #expect(accent < 4.5)
        #expect(contrast(Palette.indigoLight, Palette.night) > accent)
    }

    /// Il bottone primario: testo chiaro su indaco pieno. Non arriva a 4.5, ed è per
    /// questo che il suo testo è grande e in grassetto, dove WCAG chiede 3:1.
    @Test func primaryButtonLabelClearsTheLargeTextThreshold() {
        #expect(contrast(Palette.frost, Palette.indigo) >= 3.0)
    }

    @Test func raisedSurfaceStaysVisibleOverTheBackground() {
        #expect(contrast(Palette.nightRaised, Palette.night) > 1.1)
    }
}
