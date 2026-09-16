import Foundation
import KanjiDomain
import Testing

@testable import PaywallFeature

private enum StoreFailure: Error {
    case network
}

private final class FakeGateway: SubscriptionGateway {
    var offersToReturn: [SubscriptionOffer]
    var purchaseResult: Result<SubscriptionStatus, StoreFailure> = .success(.premium)
    var restoreResult: Result<SubscriptionStatus, StoreFailure> = .success(.premium)
    var purchased: [SubscriptionOffer.ID] = []

    init(offers: [SubscriptionOffer]) { offersToReturn = offers }

    func currentStatus() async -> SubscriptionStatus { .free }
    func offers() async throws -> [SubscriptionOffer] { offersToReturn }

    func purchase(_ offer: SubscriptionOffer) async throws -> SubscriptionStatus {
        purchased.append(offer.id)
        return try purchaseResult.get()
    }

    func restorePurchases() async throws -> SubscriptionStatus {
        try restoreResult.get()
    }
}

private final class PremiumSpy {
    var unlocked = 0
}

/// I tre piani coi prezzi decisi: 6,99 a settimana con 3 giorni di prova, 12,99 al
/// mese, 99,99 all'anno. In ordine sparso di proposito.
private let plans = [
    SubscriptionOffer(id: "yearly", period: .year, localizedPrice: "99,99 €", price: Decimal(string: "99.99")!),
    SubscriptionOffer(
        id: "weekly", period: .week, localizedPrice: "6,99 €", price: Decimal(string: "6.99")!, trialDays: 3
    ),
    SubscriptionOffer(id: "monthly", period: .month, localizedPrice: "12,99 €", price: Decimal(string: "12.99")!),
]

@Suite("Paywall")
@MainActor
struct PaywallViewModelTests {
    private func makeModel(gateway: FakeGateway, spy: PremiumSpy = PremiumSpy()) -> PaywallViewModel {
        PaywallViewModel(gateway: gateway, onPremium: { spy.unlocked += 1 })
    }

    @Test func showsPlansFromShortestToLongestWithTheTrialSelected() async {
        let model = makeModel(gateway: FakeGateway(offers: plans))

        await model.load()

        #expect(model.offers.map(\.id) == ["weekly", "monthly", "yearly"])
        #expect(model.selectedID == "weekly")
        #expect(model.phase == .ready)
    }

    /// Con questi prezzi l'annuale costa il 72% in meno a settimana: è la leva che
    /// la scala dei prezzi mette in mano, e i conti devono tornare al centesimo.
    @Test func computesTheSavingsAgainstTheWeeklyPlan() async {
        let model = makeModel(gateway: FakeGateway(offers: plans))
        await model.load()

        let savings = Dictionary(uniqueKeysWithValues: model.offers.map { ($0.id, model.savings(for: $0)) })
        #expect(savings["weekly"] == .some(nil))
        #expect(savings["monthly"] == 57)
        #expect(savings["yearly"] == 72)
    }

    @Test func buyingUnlocksPremium() async {
        let gateway = FakeGateway(offers: plans)
        let spy = PremiumSpy()
        let model = makeModel(gateway: gateway, spy: spy)
        await model.load()
        model.select(model.offers[2])

        await model.purchaseSelected()

        #expect(gateway.purchased == ["yearly"])
        #expect(spy.unlocked == 1)
        #expect(!model.lastAttemptFailed)
    }

    /// Annullare l'acquisto è una scelta, non un errore: niente messaggi rossi.
    @Test func cancellingIsNotAnError() async {
        let gateway = FakeGateway(offers: plans)
        gateway.purchaseResult = .success(.free)
        let spy = PremiumSpy()
        let model = makeModel(gateway: gateway, spy: spy)
        await model.load()

        await model.purchaseSelected()

        #expect(spy.unlocked == 0)
        #expect(!model.lastAttemptFailed)
        #expect(model.phase == .ready)
    }

    @Test func aStoreErrorLeavesThePlansUsable() async {
        let gateway = FakeGateway(offers: plans)
        gateway.purchaseResult = .failure(.network)
        let model = makeModel(gateway: gateway)
        await model.load()

        await model.purchaseSelected()

        #expect(model.lastAttemptFailed)
        #expect(model.phase == .ready)
    }

    @Test func restoringUnlocksPremium() async {
        let spy = PremiumSpy()
        let model = makeModel(gateway: FakeGateway(offers: plans), spy: spy)
        await model.load()

        await model.restore()

        #expect(spy.unlocked == 1)
    }

    @Test func noPlansIsAFailureYouCanRetry() async {
        let model = makeModel(gateway: FakeGateway(offers: []))

        await model.load()

        #expect(model.phase == .failed)
        #expect(model.selectedOffer == nil)
    }
}
