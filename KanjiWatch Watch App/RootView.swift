import SettingsFeature
import StudyFeature
import SwiftUI

/// La radice: mette insieme le due feature, che tra loro non si conoscono.
///
/// L'ingranaggio sta nella barra in alto e non nella schermata: il quadrante è
/// piccolo e l'area sotto le dita serve tutta al glifo.
struct RootView: View {
    private let container = AppContainer.shared

    var body: some View {
        NavigationStack {
            StudyView(model: container.study)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        NavigationLink {
                            SettingsView(model: container.settings, attribution: container.deck.attribution)
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
        }
    }
}
