import Foundation
import KanjiDomain
import Observation

/// Le impostazioni viste dalla UI: valori piatti, perché su un quadrante si girano
/// con la corona e non si compilano moduli.
///
/// Ogni modifica si salva subito, ma la rischedulazione aspetta: con la corona i
/// valori cambiano a raffica, e rifare 64 notifiche a ogni scatto è spreco puro.
@Observable
public final class SettingsViewModel {
    public var intervalMinutes: Int { didSet { settingsChanged() } }
    public var startHour: Int { didSet { settingsChanged() } }
    public var endHour: Int { didSet { settingsChanged() } }
    public var isPassive: Bool { didSet { settingsChanged() } }
    public var dailyLimit: Int {
        didSet {
            // I volti nuovi non possono superare le volte che l'app si fa viva:
            // sarebbe una promessa che la giornata non può mantenere. Qui si può
            // assegnare perché `newKanjiPerDay` non ha osservatori: con `@Observable`
            // il `didSet` finisce dentro il setter, e assegnarsi da lì rientrerebbe
            // all'infinito.
            newKanjiPerDay = min(newKanjiPerDay, dailyLimit)
            settingsChanged()
        }
    }
    /// Si cambia solo con `setNewKanjiPerDay`, che tiene il vincolo col numero di
    /// promemoria — come `grades` e `theme`, che hanno vincoli loro.
    public private(set) var newKanjiPerDay: Int

    /// I mazzi disponibili nel bundle, dal catalogo.
    public let levels: [KanjiLevel]
    /// I mazzi scelti. Si cambiano solo con `setGrade`, che impedisce di spegnerli
    /// tutti e di accendere quelli a pagamento senza abbonamento.
    public private(set) var grades: Set<Int>
    /// Il tema scelto. Si cambia solo con `setTheme`, che non accende i temi Premium
    /// senza abbonamento.
    public private(set) var theme: AppTheme

    public private(set) var subscription: SubscriptionStatus
    public private(set) var authorization: NotificationAuthorization = .notDetermined

    private let store: any ValueStore<ReminderSettings>
    private let authorizing: any NotificationAuthorizing
    private let rescheduleDelay: Duration
    private let onSettingsChanged: () async -> Void
    /// Interno e non privato: i test lo aspettano, invece di dormire un tempo fisso
    /// sperando che il task sia partito — che sotto carico non basta mai.
    @ObservationIgnored var pendingReschedule: Task<Void, Never>?

    public init(
        store: any ValueStore<ReminderSettings>,
        authorization: any NotificationAuthorizing,
        levels: [KanjiLevel],
        subscription: SubscriptionStatus = .free,
        rescheduleDelay: Duration = .seconds(0.8),
        onSettingsChanged: @escaping () async -> Void
    ) {
        self.store = store
        self.authorizing = authorization
        self.levels = levels
        self.subscription = subscription
        self.rescheduleDelay = rescheduleDelay
        self.onSettingsChanged = onSettingsChanged

        let current = store.load()
        // `didSet` non scatta in init: caricare non conta come modifica.
        intervalMinutes = current.intervalMinutes
        startHour = current.activeHours.startHour
        endHour = current.activeHours.endHour
        isPassive = current.isPassive
        dailyLimit = current.dailyLimit
        newKanjiPerDay = min(current.newKanjiPerDay, current.dailyLimit)
        grades = current.grades
        theme = current.theme
    }

    public var isPremium: Bool { subscription == .premium }

    /// Le impostazioni che valgono adesso, da mostrare quando i controlli sono
    /// bloccati: chi non è abbonato deve vedere il ritmo vero, non quello scelto.
    public var effective: ReminderSettings {
        AccessPolicy.effective(store.load(), for: subscription)
    }

    public func setNewKanjiPerDay(_ count: Int) {
        let clamped = min(count, dailyLimit)
        guard clamped != newKanjiPerDay else { return }
        newKanjiPerDay = clamped
        settingsChanged()
    }

    public func isLocked(_ level: KanjiLevel) -> Bool {
        !isPremium && !level.isFree
    }

    public func isLocked(_ theme: AppTheme) -> Bool {
        !isPremium && !theme.isFree
    }

    /// Il tema da mostrare adesso: scade con l'abbonamento, ma la scelta resta salvata.
    public var appliedTheme: AppTheme {
        AccessPolicy.theme(theme, for: subscription)
    }

    public func setTheme(_ chosen: AppTheme) {
        guard !isLocked(chosen), chosen != theme else { return }
        theme = chosen
        settingsChanged()
    }

    public func updateSubscription(_ status: SubscriptionStatus) {
        subscription = status
    }

    public func setGrade(_ grade: Int, enabled: Bool) {
        if enabled, let level = levels.first(where: { $0.grade == grade }), isLocked(level) {
            return
        }
        var updated = grades
        if enabled {
            updated.insert(grade)
        } else {
            updated.remove(grade)
        }
        guard !updated.isEmpty, updated != grades else { return }
        grades = updated
        settingsChanged()
    }

    /// Il permesso si può revocare da fuori: va riletto a ogni comparsa, altrimenti
    /// lo scheduler gira a vuoto e la schermata dice il falso.
    public func refreshAuthorization() async {
        authorization = await authorizing.authorizationStatus()
    }

    public func requestAuthorization() async {
        _ = await authorizing.requestAuthorization()
        await refreshAuthorization()
        await onSettingsChanged()
    }

    private func settingsChanged() {
        // Si parte da quello salvato e si tocca solo ciò che questa schermata
        // gestisce: ricostruire le impostazioni da zero cancellerebbe i campi che
        // arriveranno in futuro.
        var settings = store.load()
        settings.intervalMinutes = intervalMinutes
        settings.activeHours = ActiveHours(startHour: startHour, endHour: endHour)
        settings.isPassive = isPassive
        settings.dailyLimit = dailyLimit
        settings.newKanjiPerDay = newKanjiPerDay
        settings.grades = grades
        settings.theme = theme
        store.save(settings)

        pendingReschedule?.cancel()
        pendingReschedule = Task { [weak self, rescheduleDelay] in
            try? await Task.sleep(for: rescheduleDelay)
            guard !Task.isCancelled else { return }
            await self?.onSettingsChanged()
        }
    }
}
