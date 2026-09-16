#if os(macOS)
import AppKit
import DesignSystem
import KanjiDomain
import SwiftUI
import Testing

@testable import StudyFeature

/// La schermata renderizzata a misura di quadrante, per guardarla invece di
/// immaginarla. Le PNG finiscono in GLYPH_SNAPSHOT_DIR, se impostata.
///
/// Nota: `swift test` da riga di comando non compila i String Catalog, quindi
/// nelle immagini le scritte appaiono nella lingua sorgente (inglese).
@Suite("Rendering della schermata")
@MainActor
struct StudyViewRenderingTests {
    /// Apple Watch Series 10 da 46 mm, in punti.
    private static let watchSize = CGSize(width: 208, height: 248)

    @Test func drawsBothPhasesDifferently() throws {
        let glyph = try render(StudyView(model: makeModel()), named: "study-glyph")

        let model = makeModel()
        model.send(.tapped)
        model.send(.drawingFinished)
        model.send(.holdElapsed)
        #expect(model.state.phase == .readings)
        // Il contenuto senza ScrollView: dentro una ScrollView ImageRenderer
        // restituisce un'immagine vuota.
        let revealed = try render(
            ReadingsContent(kanji: model.kanji, glyph: model.glyph, onNext: {})
                .padding(DS.Spacing.m)
                .background(Color.dsBackground),
            named: "study-readings"
        )

        // Le due fasi devono disegnare cose diverse, e nessuna delle due
        // può essere una schermata vuota.
        #expect(inkPixels(glyph) > 500)
        #expect(inkPixels(revealed) > 500)
        #expect(inkPixels(glyph) != inkPixels(revealed))
    }

    // MARK: - Strumenti

    private func makeModel() -> StudyViewModel {
        let water = Kanji(
            character: "水",
            codepoint: "06c34",
            strokes: [
                "M52.77,15.08c1.08,1.08,1.67,2.49,1.76,5.52c0.4,14.55-0.26,62.16-0.26,67.12c0,9.78-7.52,0.03-9.02-1.22",
                "M17.5,45.75c1.75,0.62,3.73,0.43,5.25,0C25.88,44.88,36.09,41,38.59,40s4.47,1.24,3.75,3.5C39,54,28.25,69,19,74.75",
                "M81.22,27.5c-0.22,1.25-0.72,2.25-1.52,2.97c-5.64,5.1-12.45,9.78-22.45,13.78",
                "M57,46c8.82,10.73,19.23,21.46,28.42,27.42c2.16,1.4,4.52,3,7.08,3.58",
            ],
            onReadings: ["スイ"],
            kunReadings: ["みず"],
            meanings: ["water"],
            commonWord: Kanji.Word(text: "水曜日", reading: "すいようび", meanings: ["Wednesday"]),
            grade: 1,
            frequencyRank: 300
        )
        return StudyViewModel(deck: KanjiDeck(viewBox: 109, attribution: "", kanji: [water]))
    }

    private func render(_ view: some View, named name: String) throws -> NSBitmapImageRep {
        let renderer = ImageRenderer(
            content:
                view
                .frame(width: Self.watchSize.width, height: Self.watchSize.height)
        )
        renderer.scale = 2
        let bitmap = NSBitmapImageRep(cgImage: try #require(renderer.cgImage))
        if let directory = ProcessInfo.processInfo.environment["GLYPH_SNAPSHOT_DIR"],
            let png = bitmap.representation(using: .png, properties: [:])
        {
            try? png.write(to: URL(fileURLWithPath: directory).appendingPathComponent("\(name).png"))
        }
        return bitmap
    }

    private func inkPixels(_ bitmap: NSBitmapImageRep) -> Int {
        guard let data = bitmap.bitmapData, bitmap.bitsPerSample == 8 else { return 0 }
        let bytesPerPixel = bitmap.bitsPerPixel / 8
        var count = 0
        for y in 0..<bitmap.pixelsHigh {
            let row = data + y * bitmap.bytesPerRow
            for x in 0..<bitmap.pixelsWide
            where Int(row[x * bytesPerPixel]) + Int(row[x * bytesPerPixel + 1]) + Int(row[x * bytesPerPixel + 2]) > 200
            {
                count += 1
            }
        }
        return count
    }
}
#endif
