import Foundation
import KanjiDomain

/// Il negozio di prova, finché manca la chiave RevenueCat: gli stessi tre piani coi
/// prezzi decisi, acquisto e ripristino che riescono sempre senza addebiti, e lo stato
/// ricordato tra un avvio e l'altro.
///
/// Serve a provare paywall e Premium sul simulatore e su TestFlight. Per pubblicare la
/// chiave ci vuole comunque, e con lei il negozio vero prende il suo posto.
public struct SimulatedSubscriptionGateway: SubscriptionGateway {
    private static let statusKey = "debug.simulatedSubscription"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func currentStatus() async -> SubscriptionStatus {
        defaults.string(forKey: Self.statusKey).flatMap(SubscriptionStatus.init(rawValue:)) ?? .free
    }

    public func offers() async throws -> [SubscriptionOffer] {
        [
            offer("debug.weekly", .week, price: "6.99", trialDays: 3),
            offer("debug.monthly", .month, price: "12.99"),
            offer("debug.yearly", .year, price: "99.99"),
        ]
    }

    public func purchase(_ offer: SubscriptionOffer) async throws -> SubscriptionStatus {
        defaults.set(SubscriptionStatus.premium.rawValue, forKey: Self.statusKey)
        return .premium
    }

    public func restorePurchases() async throws -> SubscriptionStatus {
        await currentStatus()
    }

    private func offer(
        _ id: String,
        _ period: SubscriptionOffer.Period,
        price: String,
        trialDays: Int? = nil
    ) -> SubscriptionOffer {
        let amount = Decimal(string: price) ?? 0
        return SubscriptionOffer(
            id: id,
            period: period,
            localizedPrice: amount.formatted(.currency(code: "EUR")),
            price: amount,
            trialDays: trialDays
        )
    }
}
