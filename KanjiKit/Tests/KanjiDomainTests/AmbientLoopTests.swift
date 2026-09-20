import Foundation
import Testing

@testable import KanjiDomain

/// Il giro intero, come succede davvero: si programma la coda, passa il tempo, una
/// notifica arriva, l'app la apre, e la coda si rifà tenendone conto.
@Suite("Il giro ambientale")
struct AmbientLoopTests {
    private let deck = testDeck(count: 20)
    private let state = InMemoryStore(ReminderState.empty)
    private let ambient = InMemoryStore(AmbientState.empty)
    private let scheduler = FakeScheduler()

    private func reschedule(_ clock: @escaping () -> Date, deck: KanjiDeck? = nil) async {
        await RescheduleReminders(
            deck: deck ?? self.deck,
            settings: InMemoryStore(ReminderSettings.default),
            state: state,
            ambient: ambient,
            scheduler: scheduler,
            authorization: FakeAuthorizer(.authorized),
            now: clock,
            calendar: calendar
        ).execute()
    }

    private func loop(_ clock: @escaping () -> Date, deck: KanjiDeck? = nil) -> StudyLoop {
        StudyLoop(
            deck: deck ?? self.deck,
            settings: InMemoryStore(ReminderSettings.default),
            state: state,
            ambient: ambient,
            now: clock,
            calendar: calendar
        )
    }

    /// Notifica programmata → arrivata → aperta → coda rifatta. Lo storico cresce
    /// solo per quello che è successo davvero, e la coda nuova ne tiene conto.
    @Test func aNotificationArrivesAndTheQueueAdaptsToIt() async throws {
        var clock = date("2026-05-10 09:00")

        await reschedule({ clock })
        let planned = try #require(state.value.scheduled.min(by: { $0.fireDate < $1.fireDate }))
        #expect(state.value.scheduled.count == ReminderPlanner.systemLimit)
        // Programmare non è mostrare: finché non arriva, lo storico è vuoto.
        #expect(ambient.value.records.isEmpty)

        clock = planned.fireDate + 60
        let snapshot = try #require(loop({ clock }).current())
        #expect(snapshot.current.codepoint == planned.codepoint)
        #expect(ambient.value.records[planned.codepoint]?.presentationCount == 1)
        #expect(ambient.value.records[planned.codepoint]?.lastPresentedAt == planned.fireDate)

        _ = loop({ clock }).open(codepoint: planned.codepoint)
        loop({ clock }).readingsViewed(planned.codepoint)
        let studied = try #require(ambient.value.records[planned.codepoint])
        #expect(studied.openedCount == 1)
        #expect(studied.readingsViewedCount == 1)

        await reschedule({ clock })
        // Quello che hai davanti adesso non è anche il prossimo, e la giornata non
        // è fatta di lui solo.
        #expect(state.value.scheduled.first?.codepoint != planned.codepoint)
        let todaysQueue = state.value.scheduled.filter { calendar.isDate($0.fireDate, inSameDayAs: clock) }
        #expect(Set(todaysQueue.map(\.codepoint)).count > 1)
    }

    /// Spegnere un grado non cancella la storia dei suoi kanji, e riaccenderlo la
    /// ritrova: i record vivono per codepoint, non per mazzo caricato.
    @Test func turningAGradeOffAndOnAgainKeepsItsHistory() async throws {
        let firstHalf = KanjiDeck(viewBox: 109, attribution: "", kanji: Array(deck.kanji.prefix(10)))
        let secondHalf = KanjiDeck(viewBox: 109, attribution: "", kanji: Array(deck.kanji.suffix(10)))
        var clock = date("2026-05-10 09:00")

        await reschedule({ clock }, deck: firstHalf)
        // Passa la giornata: qualche notifica arriva davvero.
        clock = date("2026-05-10 21:00")
        _ = loop({ clock }, deck: firstHalf).current()
        let seen = ambient.value.records
        #expect(seen.count >= 3)

        // Grado spento: la coda cambia mazzo, lo storico no.
        clock = date("2026-05-11 09:00")
        await reschedule({ clock }, deck: secondHalf)
        #expect(state.value.scheduled.allSatisfy { secondHalf[$0.codepoint] != nil })
        for (codepoint, exposure) in seen {
            let kept = try #require(ambient.value.records[codepoint], "persa la storia di \(codepoint)")
            #expect(kept.firstSeenAt == exposure.firstSeenAt)
            #expect(kept.presentationCount >= exposure.presentationCount)
        }

        // Grado riacceso: si riparte da dove eravamo, non da zero.
        clock = date("2026-05-11 10:00")
        await reschedule({ clock }, deck: firstHalf)
        let first = try #require(state.value.scheduled.first)
        #expect(seen[first.codepoint] != nil)
    }
}
