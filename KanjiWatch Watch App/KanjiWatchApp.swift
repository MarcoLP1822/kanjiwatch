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
            StudyView(model: container.study)
                .onChange(of: scenePhase, initial: true) { _, phase in
                    // All'avvio e a ogni ritorno in primo piano. È il ciclo che si
                    // autoalimenta: finché apri l'app, la coda resta piena.
                    if phase == .active {
                        container.reschedule()
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
