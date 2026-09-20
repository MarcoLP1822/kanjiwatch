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
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let destination = ReminderPayload.destination(from: response.notification.request.content.userInfo)
        else { return }
        AppContainer.shared.open(destination)
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
