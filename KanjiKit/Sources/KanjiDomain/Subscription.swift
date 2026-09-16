import Foundation

/// A che punto è l'utente con l'abbonamento, visto dal dominio. Non sa niente di
/// RevenueCat né di StoreKit: se un giorno si cambia fornitore, cambia l'adattatore.
public enum SubscriptionStatus: String, Equatable, Sendable, Codable {
    case free
    case premium
}

/// Le impostazioni come le vede chi deve rispettarle: scheduler e caricamento del
/// mazzo leggono quelle effettive, ma chi salva scrive sempre le scelte vere.
public struct PolicyAppliedSettings: ValueStore {
    private let base: any ValueStore<ReminderSettings>
    private let status: () -> SubscriptionStatus

    public init(base: any ValueStore<ReminderSettings>, status: @escaping () -> SubscriptionStatus) {
        self.base = base
        self.status = status
    }

    public func load() -> ReminderSettings {
        AccessPolicy.effective(base.load(), for: status())
    }

    public func save(_ value: ReminderSettings) {
        base.save(value)
    }
}

/// Un piano in vendita, già pronto da mostrare.
public struct SubscriptionOffer: Equatable, Sendable, Identifiable {
    public enum Period: Equatable, Sendable {
        case week
        case month
        case year
    }

    /// Identificatore del prodotto sullo store.
    public let id: String
    public let period: Period
    /// Il prezzo lo formatta lo store: valuta e separatori cambiano col paese, e
    /// non sono cose da ricostruire a mano.
    public let localizedPrice: String
    /// Il prezzo numerico serve solo per confronti, come il risparmio sul settimanale.
    public let price: Decimal
    public let trialDays: Int?

    public init(id: String, period: Period, localizedPrice: String, price: Decimal, trialDays: Int? = nil) {
        self.id = id
        self.period = period
        self.localizedPrice = localizedPrice
        self.price = price
        self.trialDays = trialDays
    }
}

public enum SubscriptionError: Error, Equatable {
    /// Il piano scelto non è più tra quelli in vendita: di solito una configurazione
    /// dello store cambiata mentre l'app era aperta.
    case offerUnavailable
}

/// Chi vende gli abbonamenti.
public protocol SubscriptionGateway {
    func currentStatus() async -> SubscriptionStatus
    func offers() async throws -> [SubscriptionOffer]
    func purchase(_ offer: SubscriptionOffer) async throws -> SubscriptionStatus
    /// Obbligatorio per le linee guida di App Store: chi ha già pagato su un altro
    /// dispositivo deve poter recuperare l'acquisto.
    func restorePurchases() async throws -> SubscriptionStatus
}

/// Cosa è gratis e cosa no.
///
/// Sta nel dominio perché è una regola di prodotto: scheduler e caricamento del
/// mazzo devono rispettarla senza chiedere niente alla UI.
public enum AccessPolicy {
    public static let freeIntervalMinutes = ReminderSettings.default.intervalMinutes
    public static let freeActiveHours = ReminderSettings.default.activeHours

    /// Le impostazioni che valgono davvero per questo utente.
    ///
    /// Quelle salvate non si toccano: se l'abbonamento scade e poi si rinnova, le
    /// scelte dell'utente tornano da sole invece di essere state cancellate.
    public static func effective(_ settings: ReminderSettings, for status: SubscriptionStatus) -> ReminderSettings {
        guard status == .free else { return settings }

        var limited = settings
        limited.intervalMinutes = freeIntervalMinutes
        limited.activeHours = freeActiveHours
        let freeGrades = settings.grades.intersection(KanjiLevel.freeGrades)
        // Mai un mazzo vuoto: chi aveva scelto solo gradi a pagamento riparte da
        // quelli gratuiti.
        limited.grades = freeGrades.isEmpty ? KanjiLevel.freeGrades : freeGrades
        return limited
    }
}
