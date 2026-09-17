import DesignSystem
import KanjiDomain

extension StrokeGlyph {
    /// I tratti di un kanji insieme a come finisce ciascuno: il design system non conosce
    /// il dominio, e questa è l'unica traduzione tra i due.
    init(kanji: Kanji, viewBox: Double) throws {
        try self.init(svgPaths: kanji.strokes, endings: kanji.strokeEnds.map(Ending.init), viewBox: viewBox)
    }
}

extension StrokeGlyph.Ending {
    init(_ end: Kanji.StrokeEnd) {
        switch end {
        case .stop: self = .stop
        case .sweep: self = .sweep
        case .hook: self = .hook
        case .dot: self = .dot
        }
    }
}
