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

    @Test func findsTheLastNotificationAlreadyDelivered() {
        let state = ReminderState(
            cycle: DeckCycle(order: [], position: 0),
            scheduled: [
                ScheduledReminder(fireDate: date("2026-05-10 08:00"), codepoint: "065e5"),
                ScheduledReminder(fireDate: date("2026-05-10 09:00"), codepoint: "04e00"),
                ScheduledReminder(fireDate: date("2026-05-10 10:00"), codepoint: "056fd"),
            ]
        )

        #expect(state.lastDelivered(before: date("2026-05-10 09:12"))?.codepoint == "04e00")
        #expect(state.lastDelivered(before: date("2026-05-10 07:00")) == nil)
    }
}
