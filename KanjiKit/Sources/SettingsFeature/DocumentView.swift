import DesignSystem
import Foundation
import SwiftUI

/// Un testo lungo da scorrere col dito o con la corona: le fonti dei dati e
/// l'informativa privacy. Tutti e due devono stare dentro l'app — le licenze e App
/// Store lo chiedono — e non solo su una pagina web, che sul Watch è scomoda e vuole
/// la rete.
public struct DocumentView: View {
    private let text: String
    private let onlineURL: URL?

    public init(text: String, onlineURL: URL? = nil) {
        self.text = text
        self.onlineURL = onlineURL
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.l) {
                Text(verbatim: text)
                    .font(.dsLabel)
                    .foregroundStyle(.dsInkSecondary)
                if let onlineURL {
                    Link(destination: onlineURL) {
                        Text("Read online", bundle: .module)
                    }
                    .font(.dsLabel)
                    .foregroundStyle(.dsAccentText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DS.Spacing.m)
        }
        .background(.dsBackground)
    }
}

/// L'informativa privacy nella lingua dell'app. Sta nel bundle, così si legge anche
/// senza rete; la stessa versione va pubblicata all'indirizzo di `privacyURL`.
nonisolated enum PrivacyPolicy {
    static var text: String {
        guard
            let url = Bundle.module.url(forResource: "PrivacyPolicy", withExtension: "txt"),
            let text = try? String(contentsOf: url, encoding: .utf8)
        else { return "" }
        return text
    }
}
