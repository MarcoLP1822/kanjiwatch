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

    /// Anche il suono: sul Watch una notifica senza suono non vibra e non accende lo
    /// schermo, finisce solo nella lista. Chi aveva già detto sì senza suono lo riceve
    /// alla richiesta successiva, e il sistema non chiede niente.
    @discardableResult
    public func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
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
        // leggi alzando il polso per mezzo secondo. Nella forma col contesto il
        // titolo è la parola intera, che è proprio la cosa da leggere.
        switch notification.content {
        case .introduce:
            content.title = notification.character
            content.body = notification.meaning
        case .recall:
            content.title = notification.character
            // Nessun significato: l'invito ad aprire non è una risposta.
            content.body = String(localized: "Tap for stroke order", bundle: .module)
        case .context:
            let word = notification.word
            content.title = word?.text ?? notification.character
            content.body = [word?.reading, word?.shortMeaning].compactMap { $0 }.joined(separator: " · ")
        }
        content.userInfo = ReminderPayload.userInfo(for: notification.destination)
        content.categoryIdentifier = ReminderPayload.categoryIdentifier
        // Col suono il Watch vibra e accende lo schermo; in modalità silenziosa resta
        // la vibrazione. La modalità discreta invece non accende lo schermo e non
        // suona: la notifica si accumula nella lista, da guardare quando ti va.
        content.sound = isPassive ? nil : .default
        content.interruptionLevel = isPassive ? .passive : .active
        return content
    }
}
