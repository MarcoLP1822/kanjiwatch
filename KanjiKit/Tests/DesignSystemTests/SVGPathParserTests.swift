import KanjiData
import SwiftUI
import Testing

@testable import DesignSystem

@Suite("SVGPathParser")
struct SVGPathParserTests {
    /// Primo tratto di 水, copiato da KanjiVG.
    static let waterFirstStroke =
        "M52.77,15.08c1.08,1.08,1.67,2.49,1.76,5.52c0.4,14.55-0.26,62.16-0.26,67.12c0,9.78-7.52,0.03-9.02-1.22"

    @Test func minusDoublesAsSeparator() throws {
        let compact = try SVGPathParser.parse("M10,10c1-2,3-4,5-6")
        let spaced = try SVGPathParser.parse("M 10 10 c 1 -2 3 -4 5 -6")
        #expect(compact.path == spaced.path)
    }

    @Test func repeatsParametersWithoutRepeatingTheCommand() throws {
        let implicit = try SVGPathParser.parse("M0,0c1,1,2,2,3,3,4,4,5,5,6,6")
        let explicit = try SVGPathParser.parse("M0,0c1,1,2,2,3,3c4,4,5,5,6,6")
        #expect(implicit.path == explicit.path)
    }

    @Test func smoothCurveMirrorsThePreviousControlPoint() throws {
        // Dopo una C che finisce in (10,0) con control2 (8,0), la s deve partire da (12,0).
        let smooth = try SVGPathParser.parse("M0,0C2,0,8,0,10,0s4,0,6,0")
        let explicit = try SVGPathParser.parse("M0,0C2,0,8,0,10,0C12,0,14,0,16,0")
        #expect(smooth.path == explicit.path)
    }

    @Test func measuresLengthAlongTheCurve() throws {
        let straight = try SVGPathParser.parse("M0,0C0,25,0,75,0,100")
        #expect(abs(straight.length - 100) < 0.5)
    }

    @Test func rejectsCommandsKanjiVGNeverUses() {
        #expect(throws: SVGPathParser.Failure.unsupportedCommand("L")) {
            try SVGPathParser.parse("M0,0L10,10")
        }
    }

    @Test func keepsRealStrokesInsideTheKanjiVGSquare() throws {
        let stroke = try SVGPathParser.parse(Self.waterFirstStroke)
        let box = stroke.path.boundingRect
        #expect(box.minX >= 0 && box.minY >= 0 && box.maxX <= 109 && box.maxY <= 109)
        #expect(stroke.length > 50)
    }

    /// La rete di sicurezza vera: se un aggiornamento di KanjiVG introduce un comando
    /// nuovo, questo test diventa rosso prima che un kanji si disegni a metà.
    @Test func parsesEveryStrokeOfTheBundledDeck() throws {
        let deck = try BundledDeckRepository().loadDeck()
        #expect(!deck.isEmpty)
        for kanji in deck.kanji {
            for stroke in kanji.strokes {
                let parsed = try SVGPathParser.parse(stroke)
                #expect(!parsed.path.isEmpty, "\(kanji.character): tratto vuoto")
                #expect(parsed.length > 0, "\(kanji.character): tratto di lunghezza zero")
            }
        }
    }
}
