import Foundation
import KanjiDomain
@preconcurrency import RevenueCat

/// L'adattatore verso RevenueCat.
///
/// Tutto quello che sa di RevenueCat il resto dell'app lo trova qui: nomi dei
/// pacchetti, entitlement, conversione dei periodi di prova.
public final class RevenueCatSubscriptionGateway: SubscriptionGateway {
    /// Il nome dell'entitlement nel progetto RevenueCat: deve coincidere, altrimenti
    /// ogni acquisto andrà a buon fine e l'app continuerà a considerarti gratuito.
    public static let entitlement = "premium"

    public init(apiKey: String) {
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: apiKey)
    }

    public func currentStatus() async -> SubscriptionStatus {
        // Senza rete RevenueCat risponde dalla sua cache; se non ha nemmeno quella,
        // si resta gratuiti invece di bloccare l'app.
        guard let info = try? await Purchases.shared.customerInfo() else { return .free }
        return status(from: info)
    }

    public func offers() async throws -> [SubscriptionOffer] {
        let offerings = try await Purchases.shared.offerings()
        return (offerings.current?.availablePackages ?? []).compactMap(offer(from:))
    }

    public func purchase(_ offer: SubscriptionOffer) async throws -> SubscriptionStatus {
        let offerings = try await Purchases.shared.offerings()
        guard
            let package = offerings.current?.availablePackages.first(where: {
                $0.storeProduct.productIdentifier == offer.id
            })
        else {
            throw SubscriptionError.offerUnavailable
        }
        let result = try await Purchases.shared.purchase(package: package)
        // Annullare non è un errore: si torna al paywall con lo stato di prima.
        return status(from: result.customerInfo)
    }

    public func restorePurchases() async throws -> SubscriptionStatus {
        status(from: try await Purchases.shared.restorePurchases())
    }

    private func status(from info: CustomerInfo) -> SubscriptionStatus {
        info.entitlements[Self.entitlement]?.isActive == true ? .premium : .free
    }

    private func offer(from package: Package) -> SubscriptionOffer? {
        let period: SubscriptionOffer.Period
        switch package.packageType {
        case .weekly: period = .week
        case .monthly: period = .month
        case .annual: period = .year
        default: return nil
        }
        return SubscriptionOffer(
            id: package.storeProduct.productIdentifier,
            period: period,
            localizedPrice: package.storeProduct.localizedPriceString,
            price: package.storeProduct.price,
            trialDays: trialDays(of: package.storeProduct)
        )
    }

    private func trialDays(of product: StoreProduct) -> Int? {
        guard let discount = product.introductoryDiscount, discount.paymentMode == .freeTrial else {
            return nil
        }
        let length = discount.subscriptionPeriod.value
        switch discount.subscriptionPeriod.unit {
        case .day: return length
        case .week: return length * 7
        case .month: return length * 30
        case .year: return length * 365
        @unknown default: return nil
        }
    }
}
