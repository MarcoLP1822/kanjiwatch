import Foundation
import Testing

@testable import KanjiDomain

@Suite("Timeline della complication")
struct ComplicationTimelineTests {
    private func kanji(_ character: String, _ codepoint: String) -> Kanji {
        Kanji(
            character: character,
            codepoint: codepoint,
            strokes: ["M0,0c1,1,2,2,3,3"],
            onReadings: [],
            kunReadings: [],
            meanings: ["first", "second", "third"]
        )
    }

    private var deck: KanjiDeck {
        KanjiDeck(
            viewBox: 109, attribution: "", kanji: [kanji("日", "065e5"), kanji("一", "04e00"), kanji("国", "056fd")])
    }

    @Test func startsWithTheCurrentKanjiThenFollowsTheQueue() {
        let now = date("2026-05-10 09:12")
        let upcoming = [
            ScheduledReminder(fireDate: date("2026-05-10 11:00"), codepoint: "056fd"),
            ScheduledReminder(fireDate: date("2026-05-10 10:00"), codepoint: "04e00"),
        ]

        let entries = ComplicationTimeline.entries(now: now, current: deck.kanji[0], upcoming: upcoming, deck: deck)

        #expect(entries.map(\.character) == ["日", "一", "国"])
        #expect(entries.map(\.date) == [now, date("2026-05-10 10:00"), date("2026-05-10 11:00")])
        // Sul quadrante ci stanno due significati, non tre.
        #expect(entries[0].meaning == "first, second")
    }

    /// Il quadrante dice quello che dice la notifica di quel momento: la voce di
    /// adesso prende la forma della sessione, quelle dopo la forma della loro
    /// notifica.
    @Test func everyEntryKeepsTheFormOfItsMoment() {
        let now = date("2026-05-10 09:12")
        let upcoming = [
            ScheduledReminder(fireDate: date("2026-05-10 10:00"), codepoint: "04e00", content: .recall),
            ScheduledReminder(fireDate: date("2026-05-10 11:00"), codepoint: "056fd", content: .context),
        ]

        let entries = ComplicationTimeline.entries(
            now: now, current: deck.kanji[0], currentContent: .context, upcoming: upcoming, deck: deck)

        // Questi kanji finti non hanno parola d'esempio: il contesto ricade sul
        // significato, esattamente come farà la notifica.
        #expect(entries.map(\.content) == [.introduce, .recall, .introduce])
        #expect(entries[1].destination == ReminderDestination(codepoint: "04e00", content: .recall))
    }

    /// Con la parola d'esempio il contesto resta contesto, e la voce se la porta
    /// dietro: l'estensione non ha il mazzo per andarsela a cercare.
    @Test func theWordTravelsWithTheEntry() throws {
        let withWord = Kanji(
            character: "水",
            codepoint: "06c34",
            strokes: ["M0,0c1,1,2,2,3,3"],
            onReadings: [],
            kunReadings: [],
            meanings: ["water"],
            words: [Kanji.Word(text: "水曜日", reading: "すいようび", meanings: ["Wednesday"])]
        )
        let deck = KanjiDeck(viewBox: 109, attribution: "", kanji: [withWord])

        let entries = ComplicationTimeline.entries(
            now: date("2026-05-10 09:12"), current: withWord, currentContent: .context, upcoming: [], deck: deck)

        let entry = try #require(entries.first)
        #expect(entry.content == .context)
        #expect(entry.word == "水曜日")
        #expect(entry.wordReading == "すいようび")
        #expect(entry.wordMeaning == "Wednesday")
    }

    /// Timeline scritte prima della micro-sequenza: si leggono, e valgono come
    /// "kanji e significato".
    @Test func anEntrySavedBeforeTheSequenceIsAnIntroduce() throws {
        let saved = #"{"date":768484800,"codepoint":"065e5","character":"日","meaning":"day","strokes":["M0,0"]}"#
        let entry = try JSONDecoder().decode(GlanceEntry.self, from: Data(saved.utf8))

        #expect(entry.content == .introduce)
        #expect(entry.word == nil)
    }

    /// Il mazzo può cambiare tra la programmazione e il ricalcolo della timeline.
    @Test func skipsKanjiNoLongerInTheDeckAndRemindersAlreadyPast() {
        let now = date("2026-05-10 09:12")
        let upcoming = [
            ScheduledReminder(fireDate: date("2026-05-10 08:00"), codepoint: "04e00"),
            ScheduledReminder(fireDate: date("2026-05-10 10:00"), codepoint: "0ffff"),
            ScheduledReminder(fireDate: date("2026-05-10 11:00"), codepoint: "056fd"),
        ]

        let entries = ComplicationTimeline.entries(now: now, current: deck.kanji[0], upcoming: upcoming, deck: deck)

        #expect(entries.map(\.character) == ["日", "国"])
    }
}
