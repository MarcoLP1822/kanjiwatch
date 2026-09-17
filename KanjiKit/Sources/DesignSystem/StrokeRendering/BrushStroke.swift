import SwiftUI

/// Un tratto a pennello: la stessa linea di KanjiVG, con lo spessore che segue la
/// pressione. Il pennello entra leggero, preme, e chiude come vuole il tipo di tratto:
/// si ferma pieno, spazza assottigliandosi, scatta nell'uncino, o fa la goccia del punto.
///
/// Il contorno è un solo poligono con le punte arrotondate: niente unioni di forme né
/// sfocature, perché durante l'animazione si ricalcola a ogni fotogramma.
nonisolated struct BrushStroke: Shape {
    let samples: [CGPoint]
    let viewBox: Double
    let ending: StrokeGlyph.Ending
    /// Quanto del tratto è scritto, da 0 a 1.
    var fraction: Double
    var widthScale: CGFloat = 1

    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let scale = side / viewBox
        let spine = Self.spine(samples, upTo: fraction)
        guard spine.count > 1 else { return Path() }

        let maxWidth = side * DS.Brush.widthRatio * widthScale
        let frames = spine.indices.map { index in
            let previous = spine[max(index - 1, 0)].point
            let next = spine[min(index + 1, spine.count - 1)].point
            let dx = next.x - previous.x
            let dy = next.y - previous.y
            let length = max(hypot(dx, dy), 0.0001)
            return Frame(
                point: CGPoint(x: spine[index].point.x * scale, y: spine[index].point.y * scale),
                tangent: CGPoint(x: dx / length, y: dy / length),
                half: maxWidth * Self.width(at: spine[index].t, ending: ending) / 2
            )
        }

        var path = Path()
        for (index, frame) in frames.enumerated() {
            let point = frame.edge(across: 1)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        frames[frames.count - 1].addCap(to: &path, forward: 1)
        for frame in frames.reversed() {
            path.addLine(to: frame.edge(across: -1))
        }
        frames[0].addCap(to: &path, forward: -1)
        path.closeSubpath()
        return path
    }

    /// I campioni fino a `fraction`, ciascuno con la sua posizione lungo il tratto.
    /// L'ultimo punto è interpolato, così la punta avanza liscia e non a scatti.
    static func spine(_ samples: [CGPoint], upTo fraction: Double) -> [(point: CGPoint, t: Double)] {
        guard samples.count > 1, fraction > 0 else { return [] }
        let clamped = min(fraction, 1)
        let last = Double(samples.count - 1)
        var result: [(point: CGPoint, t: Double)] = []
        for (index, point) in samples.enumerated() {
            let t = Double(index) / last
            if t > clamped { break }
            result.append((point, t))
        }
        let position = clamped * last
        let lower = Int(position.rounded(.down))
        if Double(lower) < position, lower + 1 < samples.count {
            let from = samples[lower]
            let to = samples[lower + 1]
            let u = position - Double(lower)
            result.append((CGPoint(x: from.x + (to.x - from.x) * u, y: from.y + (to.y - from.y) * u), clamped))
        }
        return result
    }

    /// Lo spessore in un punto del tratto, come frazione di quello massimo.
    static func width(at t: Double, ending: StrokeGlyph.Ending) -> Double {
        // L'attacco: il pennello tocca la carta e preme.
        let press = 0.55 + 0.5 * smoothstep(0, 0.16, t)
        switch ending {
        case .stop:
            return press * (1 - 0.1 * smoothstep(0.2, 0.8, t)) + 0.14 * smoothstep(0.82, 1, t)
        case .sweep:
            return press * (1 - 0.95 * pow(smoothstep(0.35, 1, t), 1.15)) + 0.02
        case .hook:
            return press * (1 - 0.85 * smoothstep(0.78, 1, t)) + 0.05
        case .dot:
            return 0.45 + 0.8 * smoothstep(0, 0.6, t) - 0.1 * smoothstep(0.8, 1, t)
        }
    }

    private static func smoothstep(_ from: Double, _ to: Double, _ t: Double) -> Double {
        let x = min(max((t - from) / (to - from), 0), 1)
        return x * x * (3 - 2 * x)
    }
}

/// Un punto del tratto già in coordinate di schermo, con la direzione e il mezzo spessore.
private nonisolated struct Frame {
    let point: CGPoint
    let tangent: CGPoint
    let half: CGFloat

    /// Il bordo sinistro (`across` 1) o destro (-1) del tratto.
    func edge(across: CGFloat) -> CGPoint {
        CGPoint(x: point.x - tangent.y * half * across, y: point.y + tangent.x * half * across)
    }

    /// Mezza circonferenza da un bordo all'altro, davanti (`forward` 1) alla punta o
    /// dietro (-1) all'attacco.
    func addCap(to path: inout Path, forward: CGFloat) {
        let steps = 8
        for step in 1...steps {
            let angle = Double.pi * Double(step) / Double(steps)
            let across = cos(angle) * half * forward
            let along = sin(angle) * half * forward
            path.addLine(
                to: CGPoint(
                    x: point.x - tangent.y * across + tangent.x * along,
                    y: point.y + tangent.x * across + tangent.y * along
                )
            )
        }
    }
}
