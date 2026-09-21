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

    /// La parola scelta per quel momento viaggia nel link: toccare il quadrante che
    /// mostra 水着 apre l'app su 水着.
    @Test func theChosenWordTravelsInTheLink() {
        let destination = ReminderDestination(codepoint: "06c34", content: .context, reference: .word(1))
        let url = KanjiLink.url(for: destination)
        #expect(url.absoluteString == "kanjiwatch://kanji/06c34?content=context&wi=1")
        #expect(KanjiLink.destination(from: url) == destination)
    }

    /// Un link di prima della profondità di vocabolario apre sulla parola più comune.
    @Test func aLinkWithoutAWordOpensOnTheCommonOne() throws {
        let old = try #require(URL(string: "kanjiwatch://kanji/06c34?content=context"))
        #expect(KanjiLink.destination(from: old)?.reference == ExposureReference.none)
        #expect(KanjiLink.destination(from: old)?.content == .context)
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

    @Test func theChosenWordTravelsInTheNotification() {
        let destination = ReminderDestination(codepoint: "06c34", content: .context, reference: .word(2))
        let info = ReminderPayload.userInfo(for: destination)
        #expect(info["wi"] == "2")
        #expect(ReminderPayload.destination(from: info) == destination)
    }

    /// Notifiche già in coda quando arriva l'aggiornamento: nessuna parola scelta, e
    /// si mostra la più comune — com'era prima.
    @Test func aNotificationWithoutAWordUsesTheCommonOne() {
        let old = ReminderPayload.destination(from: ["cp": "06c34", "ec": "context"])
        #expect(old?.reference == ExposureReference.none)
        #expect(old?.content == .context)
        // E una forma senza parola non scrive `wi` per niente.
        #expect(ReminderPayload.userInfo(for: ReminderDestination(codepoint: "06c34"))["wi"] == nil)
    }

    @Test func ignoresANotificationWithoutAKanji() {
        #expect(ReminderPayload.destination(from: ["ec": "recall"]) == nil)
    }
}
