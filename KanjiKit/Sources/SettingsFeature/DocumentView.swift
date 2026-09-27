import DesignSystem
import Foundation
import SwiftUI

/// Un testo lungo da scorrere col dito o con la corona: le fonti dei dati,
/// l'informativa privacy, le condizioni d'uso. Devono stare dentro l'app — le licenze e App
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
                // L'indirizzo scritto, non un link: sul Watch non c'è un browser, e un
                // link che non si apre è peggio di niente. Lo si apre da un altro
                // dispositivo.
                if let onlineURL {
                    Text("Also online at \(Self.address(onlineURL))", bundle: .module)
                        .font(.dsLabel)
                        .foregroundStyle(.dsInkSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DS.Spacing.m)
        }
        .background(.dsBackground)
    }

    private static func address(_ url: URL) -> String {
        (url.host(percentEncoded: false) ?? "") + url.path(percentEncoded: false)
    }
}

/// L'informativa privacy nella lingua dell'app. Sta nel bundle, così si legge anche
/// senza rete; la stessa versione va pubblicata all'indirizzo di `privacyURL`.
public nonisolated enum PrivacyPolicy {
    public static var text: String { bundled("PrivacyPolicy") }
}

/// Le condizioni d'uso: l'accordo di licenza standard di Apple, e come funziona
/// l'abbonamento. Il paywall le mostra dentro l'app perché sul Watch un link al web
/// non si apre, e App Store le vuole raggiungibili.
public nonisolated enum TermsOfUse {
    public static var text: String { bundled("TermsOfUse") }
}

private nonisolated func bundled(_ name: String) -> String {
    guard
        let url = Bundle.module.url(forResource: name, withExtension: "txt"),
        let text = try? String(contentsOf: url, encoding: .utf8)
    else { return "" }
    return text
}
