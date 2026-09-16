import SwiftUI

/// La parola di esempio, con dentro acceso il kanji che stai ripassando:
/// è il modo più corto per far vedere che quel segno serve a qualcosa.
public struct WordCard: View {
    private let word: String
    private let highlighted: String
    private let reading: String
    private let meaning: String

    public init(word: String, highlighting: String, reading: String, meaning: String) {
        self.word = word
        self.highlighted = highlighting
        self.reading = reading
        self.meaning = meaning
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(marked)
                .font(.dsWord)
                .dsJapanese()
            Text(verbatim: reading)
                .font(.dsLabel)
                .foregroundStyle(.dsInkSecondary)
                .dsJapanese()
            Text(verbatim: meaning)
                .font(.dsBody)
                .foregroundStyle(.dsInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.m)
        .background(Color.dsSurface, in: .rect(cornerRadius: DS.Radius.m))
        .accessibilityElement(children: .combine)
    }

    private var marked: AttributedString {
        word.reduce(into: AttributedString()) { result, character in
            var piece = AttributedString(String(character))
            piece.foregroundColor = String(character) == highlighted ? .dsAccentText : .dsInk
            result += piece
        }
    }
}

#if DEBUG
#Preview("Parola") {
    WordCard(word: "水曜日", highlighting: "水", reading: "すいようび", meaning: "Wednesday")
        .padding(DS.Spacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dsBackground)
}
#endif
