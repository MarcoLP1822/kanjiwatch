import DesignSystem
import KanjiDomain
import Testing

/// Il dominio e il design system non si conoscono: il tema scelto passa per nome.
/// Un nome senza tema mostrerebbe in silenzio Ai-zome a chi ha pagato per un altro.
@Suite("Nomi dei temi")
struct ThemeNamesTests {
    @Test func everyChoosableThemeExistsInTheDesignSystem() {
        for theme in AppTheme.allCases {
            #expect(DSTheme.named(theme.rawValue).id == theme.rawValue)
        }
        #expect(DSTheme.all.count == AppTheme.allCases.count)
    }
}
