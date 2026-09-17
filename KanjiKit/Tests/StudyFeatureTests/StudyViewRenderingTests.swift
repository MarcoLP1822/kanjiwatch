#if os(macOS)
import AppKit
import DesignSystem
import KanjiDomain
import SwiftUI
import Testing

@testable import StudyFeature

/// La schermata renderizzata a misura di quadrante, per guardarla invece di
/// immaginarla.
///
/// Nota: `swift test` da riga di comando non compila i String Catalog, quindi
/// nelle immagini le scritte appaiono nella lingua sorgente (inglese).
@Suite("Rendering della schermata")
@MainActor
struct StudyViewRenderingTests {

    @Test func everyStepDrawsSomethingDifferent() throws {
        let kanji = try renderWatchSized(StudyView(model: makeStudyModel()), named: "study-kanji")

        let model = makeStudyModel()
        // Il contenuto senza ScrollView: dentro una ScrollView ImageRenderer
        // restituisce un'immagine vuota.
        let readings = try renderWatchSized(
            ReadingsContent(kanji: model.kanji, glyph: model.glyph, dailyLimitReached: false, onDone: {}, onNext: {})
                .padding(DS.Spacing.m)
                .background(.dsBackground),
            named: "study-readings"
        )
        let waiting = try renderWatchSized(
            WaitingContent(
                kanji: model.kanji,
                glyph: model.glyph,
                nextArrival: Date().addingTimeInterval(3600),
                dailyLimitReached: false,
                onNext: {}
            )
            .padding(DS.Spacing.m)
            .background(.dsBackground),
            named: "study-waiting"
        )
        let dayOver = try renderWatchSized(
            WaitingContent(
                kanji: model.kanji, glyph: model.glyph, nextArrival: nil, dailyLimitReached: true, onNext: {}
            )
            .padding(DS.Spacing.m)
            .background(.dsBackground),
            named: "study-day-over"
        )

        // Un tema sumi-e cambia la schermata intera: carta al posto della notte.
        let senape = try renderWatchSized(
            StudyView(model: makeStudyModel()).dsTheme(.sumiSenape), named: "study-kanji-senape")
        #expect(inkPixels(senape) > inkPixels(kanji) * 10)

        // Nessun passo può essere una schermata vuota, e nessuno uguale a un altro.
        let ink = [kanji, readings, waiting, dayOver].map(inkPixels)
        #expect(ink.allSatisfy { $0 > 500 })
        #expect(Set(ink).count == ink.count)
    }
}
#endif
