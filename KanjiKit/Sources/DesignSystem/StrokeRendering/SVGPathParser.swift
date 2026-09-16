import SwiftUI

/// Un tratto pronto da disegnare: la curva e la sua lunghezza.
/// La lunghezza serve all'animazione — un tratto lungo deve metterci di più,
/// altrimenti l'ordine di scrittura sembra sbagliato.
public struct StrokePath: Equatable, Sendable {
    public let path: Path
    public let length: Double

    public init(path: Path, length: Double) {
        self.path = path
        self.length = length
    }
}

/// Converte il campo `d` di KanjiVG in una `Path` di SwiftUI.
///
/// KanjiVG usa solo `M m C c S s` — verificato su tutti i 6702 tracciati del dump
/// 2025-08-16 — con parametri ripetuti implicitamente e il segno meno usato come
/// separatore (`0.4,14.55-0.26`). Qualsiasi altro comando è un errore esplicito:
/// meglio un test rosso che un kanji disegnato a metà.
public enum SVGPathParser {

    public enum Failure: Error, Equatable {
        case unsupportedCommand(Character)
        case malformedNumber(Character)
        case missingInitialCommand
    }

    public static func parse(_ data: String) throws -> StrokePath {
        var reader = Reader(data)
        var path = Path()
        var length = 0.0
        var current = CGPoint.zero
        /// Secondo punto di controllo dell'ultima curva: S/s lo specchia.
        var previousControl: CGPoint?
        var command: Character?
        var isFirstParameterSet = true

        while true {
            reader.skipSeparators()
            if reader.isAtEnd { break }
            if let letter = reader.readCommand() {
                command = letter
                isFirstParameterSet = true
            }
            guard let command else { throw Failure.missingInitialCommand }
            let isRelative = command.isLowercase

            // I parametri relativi guardano il punto corrente a inizio comando,
            // che non cambia mentre leggiamo le tre coppie di una curva.
            func point(_ x: Double, _ y: Double) -> CGPoint {
                isRelative ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
            }

            switch Character(command.uppercased()) {
            case "M":
                let end = point(try reader.number(command), try reader.number(command))
                if isFirstParameterSet {
                    path.move(to: end)
                } else {
                    // SVG: le coppie successive a un moveto sono lineto impliciti.
                    path.addLine(to: end)
                    length += distance(current, end)
                }
                current = end
                previousControl = nil

            case "C":
                let control1 = point(try reader.number(command), try reader.number(command))
                let control2 = point(try reader.number(command), try reader.number(command))
                let end = point(try reader.number(command), try reader.number(command))
                path.addCurve(to: end, control1: control1, control2: control2)
                length += curveLength(current, control1, control2, end)
                current = end
                previousControl = control2

            case "S":
                let control2 = point(try reader.number(command), try reader.number(command))
                let end = point(try reader.number(command), try reader.number(command))
                let control1 =
                    previousControl.map {
                        CGPoint(x: 2 * current.x - $0.x, y: 2 * current.y - $0.y)
                    } ?? current
                path.addCurve(to: end, control1: control1, control2: control2)
                length += curveLength(current, control1, control2, end)
                current = end
                previousControl = control2

            default:
                throw Failure.unsupportedCommand(command)
            }
            isFirstParameterSet = false
        }
        return StrokePath(path: path, length: length)
    }
}

// MARK: - Geometria

private func distance(_ a: CGPoint, _ b: CGPoint) -> Double {
    Double(hypot(b.x - a.x, b.y - a.y))
}

/// Lunghezza approssimata per campionamento: 16 segmenti bastano ampiamente su
/// tratti che vivono in un quadrato 109×109.
private func curveLength(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, samples: Int = 16) -> Double {
    var total = 0.0
    var previous = p0
    for step in 1...samples {
        let next = cubicPoint(p0, p1, p2, p3, at: Double(step) / Double(samples))
        total += distance(previous, next)
        previous = next
    }
    return total
}

private func cubicPoint(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, at t: Double) -> CGPoint {
    let u = 1 - t
    let a = u * u * u
    let b = 3 * u * u * t
    let c = 3 * u * t * t
    let d = t * t * t
    return CGPoint(
        x: a * p0.x + b * p1.x + c * p2.x + d * p3.x,
        y: a * p0.y + b * p1.y + c * p2.y + d * p3.y
    )
}

// MARK: - Lettura

/// Scanner minimo sul campo `d`: separatori, lettere di comando, numeri.
private struct Reader {
    private let characters: [Character]
    private var index = 0

    init(_ text: String) {
        characters = Array(text)
    }

    var isAtEnd: Bool { index >= characters.count }

    mutating func skipSeparators() {
        while index < characters.count, characters[index] == "," || characters[index].isWhitespace {
            index += 1
        }
    }

    mutating func readCommand() -> Character? {
        guard index < characters.count, characters[index].isLetter else { return nil }
        defer { index += 1 }
        return characters[index]
    }

    /// Un numero, con il meno che vale anche da separatore: "14.55-0.26" sono due numeri.
    mutating func number(_ command: Character) throws -> Double {
        skipSeparators()
        let start = index
        if index < characters.count, characters[index] == "-" || characters[index] == "+" {
            index += 1
        }
        var hasDigits = false
        var hasDot = false
        while index < characters.count {
            let character = characters[index]
            if character.isASCII, character.isNumber {
                hasDigits = true
            } else if character == ".", !hasDot {
                hasDot = true
            } else {
                break
            }
            index += 1
        }
        guard hasDigits, let value = Double(String(characters[start..<index])) else {
            throw SVGPathParser.Failure.malformedNumber(command)
        }
        return value
    }
}
