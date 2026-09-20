import DesignSystem
import KanjiData
import KanjiDomain
import StudyFeature
import SwiftUI
import UserNotifications
import WatchKit

/// La long look personalizzata: è la feature vera dell'app.
///
/// Il kanji si vede grande dentro la notifica, senza aprire niente — che è
/// letteralmente il ripasso passivo che si vuole ottenere.
final class KanjiNotificationController: WKUserNotificationHostingController<ReminderGlanceView> {
    private var kanji: Kanji?

    override func didReceive(_ notification: UNNotification) {
        let destination = ReminderPayload.destination(from: notification.request.content.userInfo)
        // Il corpo lo rivaluta il sistema dopo questo metodo: qui basta il dato.
        kanji = destination.flatMap { AppContainer.shared.deck[$0.codepoint] }
    }

    override var body: ReminderGlanceView {
        ReminderGlanceView(
            kanji: kanji,
            viewBox: AppContainer.shared.deck.viewBox,
            theme: DSTheme.named(AppContainer.shared.settings.appliedTheme.rawValue)
        )
    }
}
