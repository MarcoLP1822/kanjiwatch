import Foundation
import KanjiDomain
import Observation

/// Le impostazioni viste dalla UI: quattro valori piatti, perché su un quadrante
/// si girano con la corona e non si compilano moduli.
///
/// Ogni modifica si salva subito, ma la rischedulazione aspetta: con la corona i
/// valori cambiano a raffica, e rifare 64 notifiche a ogni scatto è spreco puro.
@Observable
public final class SettingsViewModel {
    public var intervalMinutes: Int { didSet { settingsChanged() } }
    public var startHour: Int { didSet { settingsChanged() } }
    public var endHour: Int { didSet { settingsChanged() } }
    public var isPassive: Bool { didSet { settingsChanged() } }

    public private(set) var authorization: NotificationAuthorization = .notDetermined

    private let store: any ValueStore<ReminderSettings>
    private let authorizing: any NotificationAuthorizing
    private let rescheduleDelay: Duration
    private let onSettingsChanged: () async -> Void
    @ObservationIgnored private var pendingReschedule: Task<Void, Never>?

    public init(
        store: any ValueStore<ReminderSettings>,
        authorization: any NotificationAuthorizing,
        rescheduleDelay: Duration = .seconds(0.8),
        onSettingsChanged: @escaping () async -> Void
    ) {
        self.store = store
        self.authorizing = authorization
        self.rescheduleDelay = rescheduleDelay
        self.onSettingsChanged = onSettingsChanged

        let current = store.load()
        // `didSet` non scatta in init: caricare non conta come modifica.
        intervalMinutes = current.intervalMinutes
        startHour = current.activeHours.startHour
        endHour = current.activeHours.endHour
        isPassive = current.isPassive
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
        store.save(
            ReminderSettings(
                intervalMinutes: intervalMinutes,
                activeHours: ActiveHours(startHour: startHour, endHour: endHour),
                isPassive: isPassive
            )
        )
        pendingReschedule?.cancel()
        pendingReschedule = Task { [weak self, rescheduleDelay] in
            try? await Task.sleep(for: rescheduleDelay)
            guard !Task.isCancelled else { return }
            await self?.onSettingsChanged()
        }
    }
}
