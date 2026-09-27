import Foundation
import Testing

@testable import SettingsFeature

/// L'informativa deve stare dentro l'app, nelle due lingue dell'interfaccia, e deve dire
/// la verità sull'unico servizio esterno che l'app usa.
@Suite("Informativa privacy")
struct PrivacyPolicyTests {
    @Test(arguments: ["en", "it"])
    func isBundledInEveryLanguage(language: String) throws {
        let url = try #require(
            Bundle.module.url(
                forResource: "PrivacyPolicy", withExtension: "txt", subdirectory: nil, localization: language)
        )
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.contains("RevenueCat"))
        #expect(text.contains("https://www.revenuecat.com/privacy"))
    }

    @Test func loadsInTheAppLanguage() {
        #expect(!PrivacyPolicy.text.isEmpty)
    }
}

/// Le condizioni d'uso che il paywall apre: App Store vuole la licenza e le regole
/// del rinnovo raggiungibili dal punto in cui si compra.
@Suite("Condizioni d'uso")
struct TermsOfUseTests {
    @Test(arguments: ["en", "it"])
    func isBundledInEveryLanguage(language: String) throws {
        let url = try #require(
            Bundle.module.url(
                forResource: "TermsOfUse", withExtension: "txt", subdirectory: nil, localization: language)
        )
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.contains("EULA"))
        #expect(text.contains("24"))
    }

    @Test func loadsInTheAppLanguage() {
        #expect(!TermsOfUse.text.isEmpty)
    }
}
