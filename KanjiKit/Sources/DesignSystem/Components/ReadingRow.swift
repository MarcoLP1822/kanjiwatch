import SwiftUI

/// Una riga di letture: l'etichetta e i kana.
///
/// KANJIDIC scrive l'okurigana dopo un punto (`つか.う`) e gli affissi con un
/// trattino (`-び`). Il punto non si mostra: l'okurigana si smorza, così si vede
/// a colpo d'occhio dove finisce la lettura del kanji.
public struct ReadingRow: View {
    private let label: String
    private let readings: [String]

    public init(label: String, readings: [String]) {
        self.label = label
        self.readings = readings
    }

    public var body: some View {
        if !readings.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(label)
                    .font(.dsLabel)
                    .foregroundStyle(.dsInkSecondary)
                    .textCase(.uppercase)
                Text(joined)
                    .font(.dsReading)
                    .dsJapanese()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
    }

    /// `AttributedString` e non `Text` concatenate: questo è testo-dato, non copy
    /// da localizzare, e la concatenazione di `Text` è deprecata da watchOS 26.
    private var joined: AttributedString {
        readings.enumerated().reduce(into: AttributedString()) { result, item in
            if item.offset > 0 {
                result += colored("・", .dsInkSecondary)
            }
            result += styled(item.element)
        }
    }

    private func styled(_ reading: String) -> AttributedString {
        guard let dot = reading.firstIndex(of: ".") else {
            return colored(reading, .dsInk)
        }
        return colored(String(reading[..<dot]), .dsInk)
            + colored(String(reading[reading.index(after: dot)...]), .dsInkSecondary)
    }

    private func colored(_ text: String, _ color: Color) -> AttributedString {
        var piece = AttributedString(text)
        piece.foregroundColor = color
        return piece
    }
}

#if DEBUG
#Preview("Letture") {
    VStack(alignment: .leading, spacing: DS.Spacing.l) {
        ReadingRow(label: "on", readings: ["スイ"])
        ReadingRow(label: "kun", readings: ["みず", "つか.う", "-び"])
        ReadingRow(label: "vuota", readings: [])
    }
    .padding(DS.Spacing.l)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.dsBackground)
}
#endif
