import Foundation
import KanjiDomain
import UserNotifications

/// L'adattatore verso il sistema di notifiche.
///
/// Il trigger è di calendario e non a intervallo: se cambi fuso, le notifiche
/// restano agganciate all'orario del quadrante, che è quello che conta per una
/// fascia oraria "dalle 8 alle 22".
public struct UserNotificationScheduler: ReminderScheduling, NotificationAuthorizing {
    private let center: UNUserNotificationCenter
    private let calendar: Calendar

    public init(center: UNUserNotificationCenter = .current(), calendar: Calendar = .current) {
        self.center = center
        self.calendar = calendar
    }

    public func authorizationStatus() async -> NotificationAuthorization {
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: .authorized
        case .denied: .denied
        default: .notDetermined
        }
    }

    @discardableResult
    public func requestAuthorization() async -> Bool {
        // Solo .alert: il suono è spento di proposito, il tocco aptico lo decide
        // l'utente nelle impostazioni di sistema e non è controllabile da qui.
        (try? await center.requestAuthorization(options: [.alert])) ?? false
    }

    public func replacePending(with notifications: [PlannedNotification], isPassive: Bool) async {
        center.removeAllPendingNotificationRequests()
        for notification in notifications {
            let request = UNNotificationRequest(
                identifier: identifier(for: notification),
                content: content(for: notification, isPassive: isPassive),
                trigger: UNCalendarNotificationTrigger(
                    dateMatching: calendar.dateComponents(
                        [.year, .month, .day, .hour, .minute],
                        from: notification.fireDate
                    ),
                    repeats: false
                )
            )
            try? await center.add(request)
        }
    }

    public func cancelAll() async {
        center.removeAllPendingNotificationRequests()
    }

    private func identifier(for notification: PlannedNotification) -> String {
        "kanji-\(Int(notification.fireDate.timeIntervalSince1970))"
    }

    private func content(for notification: PlannedNotification, isPassive: Bool) -> UNNotificationContent {
        let content = UNMutableNotificationContent()
        // Il kanji è il titolo, non il corpo: sul Watch il titolo è quello che
        // leggi alzando il polso per mezzo secondo.
        content.title = notification.character
        content.body = String(localized: "Tap for stroke order", bundle: .module)
        content.userInfo = ReminderPayload.userInfo(codepoint: notification.codepoint)
        content.categoryIdentifier = ReminderPayload.categoryIdentifier
        content.sound = nil
        // Modalità discreta: la notifica non accende lo schermo e si accumula
        // nella lista, da guardare quando ti va.
        content.interruptionLevel = isPassive ? .passive : .active
        return content
    }
}
