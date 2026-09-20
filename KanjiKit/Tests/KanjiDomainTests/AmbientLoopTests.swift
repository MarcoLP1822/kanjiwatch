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

    private func reschedule(
        _ clock: @escaping () -> Date,
        deck: KanjiDeck? = nil,
        mode: AmbientMode = .standard
    ) async {
        await RescheduleReminders(
            deck: deck ?? self.deck,
            settings: InMemoryStore(ReminderSettings.default),
            state: state,
            ambient: ambient,
            mode: { mode },
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

        _ = loop({ clock }).open(planned.destination)
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

    /// Il giro che rende il Premium sensato: si usa l'app gratis, i segnali si
    /// raccolgono lo stesso, e il giorno dell'acquisto il motore conosce già chi ti
    /// costa fatica. Nessuno riparte da zero al pagamento.
    @Test func whatTheFreeVersionCollectsThePremiumUsesRightAway() async throws {
        var clock = date("2026-05-10 09:00")

        // Una settimana da utente gratuito: un kanji mostrato da solo, toccato e
        // letto fino in fondo, più volte.
        let asking = deck.kanji[1].codepoint
        for day in 0..<4 {
            clock = date("2026-05-10 09:00") + Double(day) * .day
            var exposure = ambient.value
            exposure.record(.presented, codepoint: asking, content: .recall, at: clock)
            exposure.record(.opened, codepoint: asking, content: .recall, at: clock + 60)
            exposure.record(.readingsViewed, codepoint: asking, content: .recall, at: clock + 120)
            for other in [deck.kanji[0], deck.kanji[2]] {
                exposure.record(.presented, codepoint: other.codepoint, content: .recall, at: clock + 3 * .hour)
            }
            ambient.value = exposure
        }
        clock = date("2026-05-14 09:00")
        #expect(ambient.value.support(of: asking, at: clock) == .high)

        // Gratis: i segnali ci sono, ma la coda è quella di tutti.
        await reschedule({ clock }, mode: .standard)
        let free = state.value.scheduled

        // Il giorno dell'acquisto, senza aver fatto altro.
        await reschedule({ clock }, mode: .adaptive)
        let premium = state.value.scheduled

        #expect(free != premium)
        #expect(premium.count { $0.codepoint == asking } >= free.count { $0.codepoint == asking })
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
