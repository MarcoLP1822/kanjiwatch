import Foundation
import KanjiDomain
import Observation

/// Il paywall: carica i piani, ne tiene selezionato uno, compra o ripristina.
@Observable
public final class PaywallViewModel {
    public enum Phase: Equatable, Sendable {
        case loading
        case ready
        case purchasing
        case failed
    }

    public private(set) var offers: [SubscriptionOffer] = []
    public private(set) var selectedID: SubscriptionOffer.ID?
    public private(set) var phase: Phase = .loading
    /// L'ultimo acquisto o ripristino non è andato a buon fine. Annullare non conta:
    /// è una scelta, non un errore.
    public private(set) var lastAttemptFailed = false
    /// Premium è attivo: la schermata ha finito il suo lavoro e si chiude. Senza, dopo
    /// il foglio d'acquisto di Apple si tornerebbe a un paywall che chiede di nuovo di
    /// abbonarsi.
    public private(set) var isUnlocked = false

    private let gateway: any SubscriptionGateway
    private let onPremium: () -> Void

    public init(gateway: any SubscriptionGateway, onPremium: @escaping () -> Void) {
        self.gateway = gateway
        self.onPremium = onPremium
    }

    public var selectedOffer: SubscriptionOffer? {
        offers.first { $0.id == selectedID }
    }

    public func load() async {
        phase = .loading
        do {
            offers = try await gateway.offers().sorted {
                PlanPricing.weeks(in: $0.period) < PlanPricing.weeks(in: $1.period)
            }
            // Parte selezionato il piano con la prova gratuita: è quello che abbassa
            // di più la soglia per provare.
            selectedID = (offers.first { $0.trialDays != nil } ?? offers.first)?.id
            phase = offers.isEmpty ? .failed : .ready
        } catch {
            phase = .failed
        }
    }

    public func select(_ offer: SubscriptionOffer) {
        selectedID = offer.id
    }

    public func purchaseSelected() async {
        guard let offer = selectedOffer else { return }
        await attempt { try await self.gateway.purchase(offer) }
    }

    public func restore() async {
        await attempt { try await self.gateway.restorePurchases() }
    }

    /// Risparmio rispetto al settimanale, in punti percentuali interi.
    public func savings(for offer: SubscriptionOffer) -> Int? {
        guard offer.period != .week, let weekly = offers.first(where: { $0.period == .week }) else { return nil }
        return PlanPricing.savingsPercent(of: offer, comparedTo: weekly)
    }

    private func attempt(_ operation: () async throws -> SubscriptionStatus) async {
        phase = .purchasing
        lastAttemptFailed = false
        do {
            let status = try await operation()
            phase = .ready
            if status == .premium {
                isUnlocked = true
                onPremium()
            }
        } catch {
            // Un errore dello store non deve lasciare la schermata bloccata: si torna
            // ai piani e si può riprovare.
            lastAttemptFailed = true
            phase = offers.isEmpty ? .failed : .ready
        }
    }
}

/// I conti sui prezzi, separati dalla UI perché si possano provare.
enum PlanPricing {
    static func weeks(in period: SubscriptionOffer.Period) -> Decimal {
        switch period {
        case .week: 1
        case .month: Decimal(52) / 12
        case .year: 52
        }
    }

    /// Quanto costa in meno a settimana rispetto al piano settimanale. Nil se non si
    /// risparmia niente: un "risparmi lo 0%" è peggio di nessuna scritta.
    static func savingsPercent(of offer: SubscriptionOffer, comparedTo weekly: SubscriptionOffer) -> Int? {
        guard weekly.price > 0 else { return nil }
        let perWeek = offer.price / weeks(in: offer.period)
        let saved = NSDecimalNumber(decimal: 1 - perWeek / weekly.price).doubleValue
        let percent = Int((saved * 100).rounded(.down))
        return percent > 0 ? percent : nil
    }
}
