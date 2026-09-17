import SwiftUI

/// Il sigillo dei temi sumi-e: il numero dei tratti come un timbro hanko vermiglio,
/// accanto al kanji come la firma accanto a un dipinto. 画 è il contatore dei tratti.
public struct KanjiSeal: View {
    private let strokeCount: Int

    public init(strokeCount: Int) {
        self.strokeCount = strokeCount
    }

    public var body: some View {
        Text(verbatim: "\(strokeCount)画")
            .font(.dsLabel.weight(.heavy))
            .foregroundStyle(.dsOnAccent)
            .padding(.horizontal, DS.Spacing.s)
            .padding(.vertical, DS.Spacing.xs)
            .background(.dsAccent, in: .rect(cornerRadius: DS.Spacing.xs))
            .rotationEffect(.degrees(-5))
            .dsJapanese()
            // Il numero dei tratti non dice niente a chi non vede il kanji disegnato.
            .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview("Sigillo") {
    KanjiSeal(strokeCount: 4)
        .padding(DS.Spacing.l)
        .background(.dsBackground)
        .dsTheme(.sumiWashi)
}
#endif
