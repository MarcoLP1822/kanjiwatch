#if os(macOS)
import AppKit
import KanjiData
import SwiftUI
import Testing

@testable import DesignSystem

/// L'icona dell'app si disegna coi token e coi tratti veri di 字 ("carattere"), non si
/// ritocca a mano: se cambia la palette, si rigenera.
///
///     APP_ICON_OUTPUT="…/AppIcon.appiconset/AppIcon.png" swift test --filter AppIconTests
@Suite("Icona dell'app")
@MainActor
struct AppIconTests {
    @Test func drawsTheKanjiOnTheAccent() throws {
        let deck = try BundledDeckRepository().loadDeck(grades: [1])
        let kanji = try #require(deck["05b57"])
        let glyph = try StrokeGlyph(svgPaths: kanji.strokes, viewBox: deck.viewBox)

        let renderer = ImageRenderer(content: AppIcon(glyph: glyph).frame(width: 1024, height: 1024))
        renderer.scale = 1
        // App Store rifiuta le icone con trasparenza.
        renderer.isOpaque = true
        let bitmap = NSBitmapImageRep(cgImage: try #require(renderer.cgImage))

        #expect(bitmap.pixelsWide == 1024 && bitmap.pixelsHigh == 1024)
        #expect(!bitmap.hasAlpha)
        // Un campione ogni quattro pixel: 5.000 campioni sono circa il 2% dell'icona.
        #expect(strokePixels(bitmap) > 5_000)

        if let path = ProcessInfo.processInfo.environment["APP_ICON_OUTPUT"] {
            let png = try #require(bitmap.representation(using: .png, properties: [:]))
            try png.write(to: URL(fileURLWithPath: path))
        }
    }

    /// Pixel quasi bianchi: sul fondo indaco sono solo i tratti.
    private func strokePixels(_ bitmap: NSBitmapImageRep) -> Int {
        var count = 0
        for y in stride(from: 0, to: bitmap.pixelsHigh, by: 2) {
            for x in stride(from: 0, to: bitmap.pixelsWide, by: 2) {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                if color.redComponent > 0.8, color.greenComponent > 0.8, color.blueComponent > 0.8 {
                    count += 1
                }
            }
        }
        return count
    }
}

/// Indaco pieno e tratti chiari: sulla griglia nera delle app si riconosce anche a 40
/// punti. Il margine tiene il kanji dentro la maschera rotonda di watchOS.
private struct AppIcon: View {
    let glyph: StrokeGlyph

    var body: some View {
        KanjiGlyphMark(glyph: glyph)
            .foregroundStyle(.dsInk)
            .padding(230)
            .background(.dsAccent)
    }
}
#endif
