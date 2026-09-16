#if os(macOS)
import AppKit
import KanjiDomain
import SwiftUI
import Testing

@testable import StudyFeature

@Suite("Rendering della notifica")
@MainActor
struct GlanceRenderingTests {

    @Test func showsTheGlyphAndTheMeaning() throws {
        let glance = try renderWatchSized(ReminderGlanceView(kanji: waterKanji, viewBox: 109), named: "glance")
        #expect(inkPixels(glance) > 500)
    }

    /// Il mazzo può cambiare tra quando la notifica viene programmata e quando
    /// arriva: con un kanji che non c'è più, la notifica resta vuota ma non si
    /// rompe.
    @Test func survivesAKanjiThatIsNoLongerInTheDeck() throws {
        let empty = try renderWatchSized(ReminderGlanceView(kanji: nil, viewBox: 109), named: "glance-empty")
        #expect(inkPixels(empty) == 0)
    }
}
#endif
