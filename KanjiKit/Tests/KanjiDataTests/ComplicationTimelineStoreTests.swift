import Foundation
import KanjiDomain
import Testing

@testable import KanjiData

@Suite("Timeline condivisa con la complication")
struct ComplicationTimelineStoreTests {
    /// App e complication sono due processi: quello che scrive uno lo deve rileggere
    /// l'altro identico, tratti compresi.
    @Test func whatTheAppWritesTheComplicationReadsBack() throws {
        let defaults = try #require(UserDefaults(suiteName: "test.complication.\(UUID().uuidString)"))
        let day = try #require(try BundledDeckRepository().loadDeck(grades: [1])["065e5"])
        let entries = [
            GlanceEntry(date: Date(timeIntervalSince1970: 1_000), kanji: day),
            GlanceEntry(date: Date(timeIntervalSince1970: 4_600), kanji: day),
        ]

        UserDefaultsStore<[GlanceEntry]>.complicationTimeline(defaults: defaults).save(entries)
        let reloaded = UserDefaultsStore<[GlanceEntry]>.complicationTimeline(defaults: defaults).load()

        #expect(reloaded == entries)
        #expect(reloaded.first?.strokes.count == 4)
    }

    @Test func anEmptyContainerMeansAnEmptyTimeline() throws {
        let defaults = try #require(UserDefaults(suiteName: "test.complication.\(UUID().uuidString)"))
        #expect(UserDefaultsStore<[GlanceEntry]>.complicationTimeline(defaults: defaults).load().isEmpty)
    }
}
