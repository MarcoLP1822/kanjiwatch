import DesignSystem
import PaywallFeature
import SettingsFeature
import StudyFeature
import SwiftUI

/// La radice: mette insieme le feature, che tra loro non si conoscono.
///
/// L'ingranaggio sta nella barra in alto e non nella schermata: il quadrante è
/// piccolo e l'area sotto le dita serve tutta al glifo.
struct RootView: View {
    private let container = AppContainer.shared

    private var theme: DSTheme {
        DSTheme.named(container.settings.appliedTheme.rawValue)
    }

    var body: some View {
        NavigationStack {
            StudyView(model: container.study)
                .dsTheme(theme)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        NavigationLink {
                            SettingsView(model: container.settings, attribution: container.catalog.attribution) {
                                PaywallScreen()
                            }
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
        }
    }
}

/// Il paywall tiene il suo view model in `@State`: la destinazione di un link si
/// ricostruisce spesso, e ricaricare i piani dallo store a ogni ricostruzione è inutile.
private struct PaywallScreen: View {
    @State private var model = AppContainer.shared.makePaywall()

    var body: some View {
        PaywallView(
            model: model,
            termsURL: AppConfiguration.termsOfUseURL,
            privacyURL: AppConfiguration.privacyPolicyURL
        )
    }
}
