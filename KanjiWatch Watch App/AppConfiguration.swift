import Foundation

/// I valori che dipendono dall'account e non dal codice. Stanno tutti qui, così
/// quando arrivano si compilano in un posto solo.
enum AppConfiguration {
    /// Chiave pubblica dell'app su RevenueCat (Project settings › API keys, quella
    /// che comincia con "appl_"): è pensata per stare nel binario. Finché è vuota
    /// l'app usa il negozio di prova, che dà il Premium a chiunque senza addebiti:
    /// va bene per TestFlight, non per l'App Store.
    #warning("Incolla la chiave pubblica RevenueCat prima di pubblicare: senza, il Premium è gratis")
    static let revenueCatAPIKey = ""

    /// Le condizioni d'uso standard di Apple, valide finché non ne scrivi di tue.
    static let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    /// App Store la chiede per ogni abbonamento. Finché manca il link non compare:
    /// meglio nessun link che uno che porta alla privacy policy di qualcun altro.
    #warning("Inserisci l'indirizzo della privacy policy prima della pubblicazione")
    static let privacyPolicyURL: URL? = nil
}
