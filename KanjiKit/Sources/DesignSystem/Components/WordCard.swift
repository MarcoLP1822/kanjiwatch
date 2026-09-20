import SwiftUI

/// La parola col kanji che stai ripassando acceso dentro.
///
/// Sta qui e non dentro `WordCard` perché la usano in due: la schermata delle
/// letture e la notifica che mostra il kanji dentro una parola vera. Una regola
/// d'evidenziazione sola, in un posto solo.
public struct HighlightedWord: View {
    private let word: String
    private let highlighted: String
    @Environment(\.dsTheme) private var theme

    public init(_ word: String, highlighting: String) {
        self.word = word
        self.highlighted = highlighting
    }

    public var body: some View {
        Text(marked).dsJapanese()
    }

    private var marked: AttributedString {
        word.reduce(into: AttributedString()) { result, character in
            var piece = AttributedString(String(character))
            piece.foregroundColor = theme.color(String(character) == highlighted ? .accentText : .ink)
            result += piece
        }
    }
}

/// La parola di esempio con la sua lettura e il suo significato: è il modo più corto
/// per far vedere che quel segno serve a qualcosa.
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
            HighlightedWord(word, highlighting: highlighted)
                .font(.dsWord)
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
        .background(.dsSurface, in: .rect(cornerRadius: DS.Radius.m))
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview("Parola") {
    WordCard(word: "水曜日", highlighting: "水", reading: "すいようび", meaning: "Wednesday")
        .padding(DS.Spacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.dsBackground)
}
#endif
