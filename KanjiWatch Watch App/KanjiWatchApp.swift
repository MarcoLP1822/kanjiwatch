import StudyFeature
import SwiftUI

@main
struct KanjiWatchApp: App {
    private let container = AppContainer.shared

    var body: some Scene {
        WindowGroup {
            StudyView(model: container.study)
        }
    }
}
