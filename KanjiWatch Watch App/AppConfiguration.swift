import Foundation

/// I valori che dipendono dall'account e non dal codice. Stanno tutti qui, così
/// quando arrivano si compilano in un posto solo.
enum AppConfiguration {
    /// Chiave pubblica dell'app su RevenueCat (Project settings › API keys, quella
    /// che comincia con "appl_"): è pensata per stare nel binario. Finché è vuota
    /// l'app gira gratuita e il paywall dice che i piani non si possono caricare.
    #warning("Incolla la chiave pubblica RevenueCat per provare gli acquisti")
    static let revenueCatAPIKey = ""

    /// Le condizioni d'uso standard di Apple, valide finché non ne scrivi di tue.
    static let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    /// App Store la chiede per ogni abbonamento. Finché manca il link non compare:
    /// meglio nessun link che uno che porta alla privacy policy di qualcun altro.
    #warning("Inserisci l'indirizzo della privacy policy prima della pubblicazione")
    static let privacyPolicyURL: URL? = nil
}
