import KanjiData
import StudyFeature
import SwiftUI

@main
struct KanjiWatchApp: App {
    @WKApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @Environment(\.scenePhase) private var scenePhase

    private let container = AppContainer.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .onOpenURL { url in
                    // Dalla complication: apre sul kanji che era sul quadrante, nella
                    // forma in cui lo stavi guardando.
                    if let destination = KanjiLink.destination(from: url) {
                        container.open(destination)
                    }
                }
                .onChange(of: scenePhase, initial: true) { _, phase in
                    if phase == .active {
                        container.becameActive()
                    }
                }
        }

        // La categoria deve coincidere con quella scritta nel contenuto della
        // notifica, altrimenti il sistema mostra la long look di default.
        WKNotificationScene(
            controller: KanjiNotificationController.self,
            category: ReminderPayload.categoryIdentifier
        )
    }
}
