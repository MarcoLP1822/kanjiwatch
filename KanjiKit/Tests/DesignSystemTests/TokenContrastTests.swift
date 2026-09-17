import Foundation
import Testing

@testable import DesignSystem

/// Il contrasto è una proprietà dei temi, non della singola schermata: se qualcuno
/// ritocca una palette, questi test cadono prima che l'app diventi illeggibile al sole.
@Suite("Contrasto dei temi")
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

    /// Tutto il testo piccolo, sul fondo e sulle superfici dove compare: WCAG chiede 4.5:1.
    @Test(arguments: DSTheme.all)
    func everyTextTokenIsReadable(_ theme: DSTheme) {
        let palette = theme.palette
        for text in [palette.ink, palette.inkSecondary, palette.accentText] {
            #expect(contrast(text, palette.background) >= 4.5, "\(theme.id)")
            #expect(contrast(text, palette.surface) >= 4.5, "\(theme.id)")
        }
        #expect(contrast(palette.warning, palette.background) >= 4.5, "\(theme.id)")
    }

    /// L'accento pieno è per forme e tratti, dove basta 3:1. Il testo dei bottoni pieni
    /// è grande e in grassetto: anche lì la soglia WCAG è 3:1.
    @Test(arguments: DSTheme.all)
    func fullAccentWorksAsShapeAndUnderLargeText(_ theme: DSTheme) {
        #expect(contrast(theme.palette.accent, theme.palette.background) >= 3.0, "\(theme.id)")
        #expect(contrast(theme.palette.onAccent, theme.palette.accent) >= 3.0, "\(theme.id)")
    }

    @Test(arguments: DSTheme.all)
    func surfaceStaysVisibleOverTheBackground(_ theme: DSTheme) {
        #expect(contrast(theme.palette.surface, theme.palette.background) > 1.1, "\(theme.id)")
    }

    /// Il motivo per cui Ai-zome ha due indaco: quello pieno non regge il testo piccolo.
    @Test func aiZomeFullAccentIsForGraphicsOnly() {
        let palette = DSTheme.aiZome.palette
        #expect(contrast(palette.accent, palette.background) < 4.5)
        #expect(contrast(palette.accentText, palette.background) > contrast(palette.accent, palette.background))
    }

    @Test func themesHaveDistinctNamesAndAnUnknownOneFallsBack() {
        #expect(Set(DSTheme.all.map(\.id)).count == DSTheme.all.count)
        #expect(DSTheme.named("sconosciuto") == .aiZome)
    }
}
