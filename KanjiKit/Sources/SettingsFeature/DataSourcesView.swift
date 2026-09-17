import DesignSystem
import SwiftUI

/// Le fonti dei dati.
///
/// Non è una cortesia: KanjiVG e i file EDRDG sono CC BY-SA, e la licenza chiede
/// che l'attribuzione sia visibile dentro l'app, non nascosta nella descrizione
/// su App Store. Il testo viaggia dentro kanji.json, così non può separarsi dai
/// dati che descrive.
public struct DataSourcesView: View {
    private let text: String

    public init(text: String) {
        self.text = text
    }

    public var body: some View {
        ScrollView {
            Text(verbatim: text)
                .font(.dsLabel)
                .foregroundStyle(.dsInkSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DS.Spacing.m)
        }
        .background(.dsBackground)
    }
}
