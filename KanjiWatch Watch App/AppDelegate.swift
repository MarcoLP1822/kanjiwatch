import KanjiData
import UserNotifications
import WatchKit

/// Il delegate delle notifiche.
///
/// Va impostato prima che possa arrivare la prima risposta, quindi nel ciclo di
/// vita dell'app e non in `onAppear` di una view: se arriva un tocco su una
/// notifica mentre l'app è ancora chiusa, quel tocco si perde.
final class AppDelegate: NSObject, WKApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching() {
        UNUserNotificationCenter.current().delegate = self
        scheduleRefresh()
    }

    func applicationDidEnterBackground() {
        scheduleRefresh()
    }

    /// Il risveglio in background: rifà la coda e il quadrante anche per chi l'app non
    /// la apre mai, poi chiede il prossimo.
    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            guard let refresh = task as? WKApplicationRefreshBackgroundTask else {
                task.setTaskCompletedWithSnapshot(false)
                continue
            }
            Task {
                await AppContainer.shared.refreshInBackground()
                scheduleRefresh()
                refresh.setTaskCompletedWithSnapshot(false)
            }
        }
    }

    /// Ogni quattro ore, se watchOS lo concede: il momento lo decide lui, secondo il
    /// budget dell'app. La coda dura almeno due giorni, quindi anche un ritardo va bene.
    private func scheduleRefresh() {
        WKApplication.shared().scheduleBackgroundRefresh(
            withPreferredDate: .now.addingTimeInterval(4 * 3600),
            userInfo: nil
        ) { _ in }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let destination = ReminderPayload.destination(from: response.notification.request.content.userInfo)
        else { return }
        if response.actionIdentifier == ReminderPayload.forgotActionIdentifier {
            await AppContainer.shared.forgot(destination)
        } else {
            AppContainer.shared.open(destination)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Se l'app è già aperta la notifica resta nella lista: interrompere chi
        // sta già ripassando non ha senso.
        [.list]
    }
}
