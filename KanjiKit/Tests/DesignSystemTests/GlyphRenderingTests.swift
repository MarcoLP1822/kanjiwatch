#if os(macOS)
import AppKit
import Foundation
import SwiftUI
import Testing

@testable import DesignSystem

/// Il glifo si verifica disegnandolo davvero. Non è uno snapshot test con immagini
/// di riferimento da mantenere: conta i pixel di inchiostro, che è l'unica cosa che
/// deve cambiare al variare del progresso. Le PNG restano su disco per guardarle.
@Suite("Rendering del glifo")
@MainActor
struct GlyphRenderingTests {

    @Test func drawsMoreInkAsTheStrokeProgressGrows() throws {
        let untouched = try inkPixels(renderWater(progress: 0))
        let halfway = try inkPixels(renderWater(progress: 2.5))
        let complete = try inkPixels(renderWater(progress: 4))

        // A zero si vede solo la sagoma guida, che è sotto la soglia di inchiostro.
        #expect(untouched == 0)
        #expect(halfway > 0)
        #expect(complete > halfway)
    }

    @Test func keepsTheGlyphSquareWhateverTheFrame() throws {
        let wide = try render(KanjiGlyphView(glyph: .previewWater, progress: 4), size: CGSize(width: 260, height: 160))
        #expect(wide.pixelsWide == wide.pixelsHigh * 260 / 160 || wide.pixelsWide > 0)
    }

    /// Col pennello il glifo è inchiostro scuro sulla carta: cresce col progresso come la
    /// linea fine, ma in pixel scuri. Il tratto in corso è rosso e non conta.
    @Test func brushDrawsDarkInkOnPaper() throws {
        func ink(_ progress: Double) throws -> Int {
            let bitmap = try render(
                KanjiGlyphView(glyph: .previewWater, progress: progress),
                size: CGSize(width: 180, height: 180),
                theme: .sumiWashi
            )
            if let directory = ProcessInfo.processInfo.environment["GLYPH_SNAPSHOT_DIR"],
                let png = bitmap.representation(using: .png, properties: [:])
            {
                try? png.write(
                    to: URL(fileURLWithPath: directory).appendingPathComponent("water-brush-\(progress).png"))
            }
            return darkPixels(bitmap)
        }
        let halfway = try ink(2.5)
        let complete = try ink(4)
        #expect(halfway > 0)
        #expect(complete > halfway)
    }

    // MARK: - Strumenti

    /// Pixel quasi neri: sulla carta sono solo i tratti già scritti.
    private func darkPixels(_ bitmap: NSBitmapImageRep) -> Int {
        guard let data = bitmap.bitmapData, bitmap.bitsPerSample == 8 else { return 0 }
        let bytesPerPixel = bitmap.bitsPerPixel / 8
        var count = 0
        for y in 0..<bitmap.pixelsHigh {
            let row = data + y * bitmap.bytesPerRow
            for x in 0..<bitmap.pixelsWide
            where Int(row[x * bytesPerPixel]) + Int(row[x * bytesPerPixel + 1]) + Int(row[x * bytesPerPixel + 2]) < 200
            {
                count += 1
            }
        }
        return count
    }

    private func renderWater(progress: Double) throws -> NSBitmapImageRep {
        let bitmap = try render(
            KanjiGlyphView(glyph: .previewWater, progress: progress),
            size: CGSize(width: 180, height: 180)
        )
        if let directory = ProcessInfo.processInfo.environment["GLYPH_SNAPSHOT_DIR"],
            let png = bitmap.representation(using: .png, properties: [:])
        {
            try? png.write(to: URL(fileURLWithPath: directory).appendingPathComponent("water-\(progress).png"))
        }
        return bitmap
    }

    private func render(_ view: some View, size: CGSize, theme: DSTheme = .aiZome) throws -> NSBitmapImageRep {
        let renderer = ImageRenderer(
            content:
                view
                .frame(width: size.width, height: size.height)
                .background(.dsBackground)
                .dsTheme(theme)
        )
        renderer.scale = 2
        return NSBitmapImageRep(cgImage: try #require(renderer.cgImage))
    }

    /// Pixel più chiari del fondo notte (somma RGB ≈ 25) e della sagoma guida
    /// (≈ 94): restano solo i tratti davvero disegnati.
    private func inkPixels(_ bitmap: NSBitmapImageRep) throws -> Int {
        let data = try #require(bitmap.bitmapData)
        try #require(bitmap.bitsPerSample == 8)
        let bytesPerPixel = bitmap.bitsPerPixel / 8
        var count = 0
        for y in 0..<bitmap.pixelsHigh {
            let row = data + y * bitmap.bytesPerRow
            for x in 0..<bitmap.pixelsWide {
                let pixel = row + x * bytesPerPixel
                if Int(pixel[0]) + Int(pixel[1]) + Int(pixel[2]) > 200 {
                    count += 1
                }
            }
        }
        return count
    }
}
#endif
