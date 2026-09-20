import Foundation
import KanjiDomain
import Testing

@testable import KanjiData

@Suite("Collegamento al kanji")
struct KanjiLinkTests {
    @Test func whatTheComplicationBuildsTheAppReadsBack() {
        let url = KanjiLink.url(for: ReminderDestination(codepoint: "06c34", content: .context))
        #expect(url.absoluteString == "kanjiwatch://kanji/06c34?content=context")
        #expect(KanjiLink.destination(from: url) == ReminderDestination(codepoint: "06c34", content: .context))
    }

    /// Un quadrante aggiornato prima dell'app, o un link rimasto in giro: si apre
    /// come si apriva prima, non si perde.
    @Test func aLinkWithoutAFormOpensAsAnIntroduce() throws {
        let old = try #require(URL(string: "kanjiwatch://kanji/06c34"))
        #expect(KanjiLink.destination(from: old) == ReminderDestination(codepoint: "06c34", content: .introduce))
    }

    @Test func ignoresLinksThatAreNotOurs() throws {
        #expect(KanjiLink.destination(from: try #require(URL(string: "https://example.com/06c34"))) == nil)
        #expect(KanjiLink.destination(from: try #require(URL(string: "kanjiwatch://kanji/"))) == nil)
    }
}

@Suite("Contenuto della notifica")
struct ReminderPayloadTests {
    @Test func whatTheSchedulerWritesTheAppReadsBack() {
        let destination = ReminderDestination(codepoint: "06c34", content: .recall)
        #expect(ReminderPayload.destination(from: ReminderPayload.userInfo(for: destination)) == destination)
    }

    /// Notifiche già in coda quando l'app si aggiorna: la forma non c'è, e vale
    /// quella con cui erano state pensate.
    @Test func aNotificationWithoutAFormIsAnIntroduce() {
        #expect(
            ReminderPayload.destination(from: ["cp": "06c34"])
                == ReminderDestination(codepoint: "06c34", content: .introduce))
    }

    @Test func ignoresANotificationWithoutAKanji() {
        #expect(ReminderPayload.destination(from: ["ec": "recall"]) == nil)
    }
}
