import KanjiDomain

/// Il negozio quando non c'è ancora: nessuna chiave RevenueCat configurata.
///
/// L'app deve girare lo stesso — gratuita, col paywall che dice onestamente che i
/// piani non si possono caricare — invece di andare in crash all'avvio perché
/// qualcuno ha configurato l'SDK con una chiave vuota.
public struct UnavailableSubscriptionGateway: SubscriptionGateway {
    public init() {}

    public func currentStatus() async -> SubscriptionStatus { .free }

    public func offers() async throws -> [SubscriptionOffer] { [] }

    public func purchase(_ offer: SubscriptionOffer) async throws -> SubscriptionStatus {
        throw SubscriptionError.offerUnavailable
    }

    public func restorePurchases() async throws -> SubscriptionStatus { .free }
}
