import Foundation
import Testing

@testable import KanjiDomain

/// I kanji saltati: arrivati con una notifica che non hai aperto. A giornata finita si
/// possono vedere subito o farseli rimandare; in nessuno dei due casi contano di nuovo
/// nella giornata, che li aveva già avuti.
@Suite("Kanji saltati")
struct MissedKanjiTests {
    private func delivered(_ time: String, _ codepoint: String) -> DeliveredReminder {
        DeliveredReminder(
            identifier: "\(time)-\(codepoint)", date: date(time),
            destination: ReminderDestination(codepoint: codepoint, content: .recall))
    }

    /// Solo quelli di oggi, uno per kanji, in ordine d'arrivo — e non quello che l'app
    /// ti sta mostrando.
    @Test func onlyTodaysOnceEachAndNotTheOneOnScreen() {
        let missed = MissedToday.destinations(
            from: [
                delivered("2026-05-10 11:00", "bbbbb"), delivered("2026-05-09 21:00", "zzzzz"),
                delivered("2026-05-10 10:00", "aaaaa"), delivered("2026-05-10 12:00", "aaaaa"),
                delivered("2026-05-10 13:00", "ccccc"),
            ],
            showing: "ccccc", now: date("2026-05-10 15:20"), calendar: calendar)

        #expect(missed.map(\.codepoint) == ["aaaaa", "bbbbb"])
        // Tornano nella forma in cui erano arrivati.
        #expect(missed.first?.content == .recall)
    }

    /// Uno per intervallo da adesso, al minuto, e solo dentro la fascia di oggi.
    @Test func replaysComeOneIntervalApartInsideTodaysWindow() {
        let missed = ["aaaaa", "bbbbb", "ccccc"].map { ReminderDestination(codepoint: $0) }
        let settings = ReminderSettings.default

        let replays = ReminderPlanner.replays(
            of: missed, now: date("2026-05-10 19:40").addingTimeInterval(25), settings: settings, calendar: calendar)

        #expect(replays.map(\.fireDate) == [date("2026-05-10 20:40"), date("2026-05-10 21:40")])
        #expect(replays.map(\.codepoint) == ["aaaaa", "bbbbb"])
        // Fuori fascia non si rimanda niente: ci pensa il motore, nei giorni dopo.
        #expect(ReminderPlanner.replays(of: missed, now: date("2026-05-10 22:30"), settings: settings, calendar: calendar).isEmpty)
    }

    @Test func aReplayShowsTheKanjiButDoesNotCountAgain() {
        let now = date("2026-05-10 15:31")
        var value = ReminderState(
            session: StudySession(codepoint: "old00", isDone: true, since: date("2026-05-10 15:15")),
            today: DailyCount(day: date("2026-05-10 00:00"), count: 30),
            replays: [ScheduledReminder(fireDate: date("2026-05-10 15:30"), codepoint: "aaaaa")]
        )

        let arrived = value.recordDeliveries(now: now, calendar: calendar)

        #expect(arrived.map(\.codepoint) == ["aaaaa"])
        #expect(value.replays.isEmpty)
        #expect(value.today.count(on: now, calendar: calendar) == 30)
        #expect(value.session.codepoint == "aaaaa")
        #expect(!value.session.isDone)
    }

    /// "Un altro adesso" anticipa anche un recupero, senza contarlo.
    @Test func nextBringsAReplayForwardWithoutCountingIt() {
        let now = date("2026-05-10 15:20")
        var value = ReminderState(
            scheduled: [ScheduledReminder(fireDate: date("2026-05-11 08:00"), codepoint: "zzzzz")],
            session: StudySession(codepoint: "old00", isDone: true, since: date("2026-05-10 15:15")),
            today: DailyCount(day: date("2026-05-10 00:00"), count: 30),
            replays: [ScheduledReminder(fireDate: date("2026-05-10 15:30"), codepoint: "aaaaa")]
        )

        let outcome = value.advance(after: "old00", now: now, dailyLimit: nil, draw: { nil }, calendar: calendar)

        #expect(outcome == .showing("aaaaa"))
        #expect(value.replays.isEmpty)
        #expect(value.scheduled.count == 1)
        #expect(value.today.count(on: now, calendar: calendar) == 30)
    }

    /// Il piano rifà la coda da zero, ma i recuperi restano, e arrivano al polso con le
    /// altre notifiche, in ordine e dentro il limite di sistema.
    @Test func replaysSurviveTheReplanAndReachTheWatch() async {
        let replay = ScheduledReminder(fireDate: date("2026-05-10 09:40"), codepoint: testCodepoint(7), content: .introduce)
        let state = InMemoryStore(ReminderState(replays: [replay]))
        let scheduler = FakeScheduler()
        let useCase = RescheduleReminders(
            deck: testDeck(count: 60), settings: InMemoryStore(.default), state: state, ambient: InMemoryStore(.empty),
            scheduler: scheduler, authorization: FakeAuthorizer(.authorized), now: { date("2026-05-10 09:12") },
            calendar: calendar)

        await useCase.execute()

        #expect(state.value.replays == [replay])
        #expect(scheduler.notifications.count <= ReminderPlanner.systemLimit)
        #expect(scheduler.notifications.contains { $0.fireDate == replay.fireDate && $0.codepoint == replay.codepoint })
        #expect(scheduler.notifications.map(\.fireDate) == scheduler.notifications.map(\.fireDate).sorted())
    }

    @Test func withoutPermissionNothingIsReplayed() async {
        let state = InMemoryStore(
            ReminderState(replays: [ScheduledReminder(fireDate: date("2026-05-10 09:40"), codepoint: testCodepoint(7))]))
        let useCase = RescheduleReminders(
            deck: testDeck(count: 60), settings: InMemoryStore(.default), state: state, ambient: InMemoryStore(.empty),
            scheduler: FakeScheduler(), authorization: FakeAuthorizer(.denied), now: { date("2026-05-10 09:12") },
            calendar: calendar)

        await useCase.execute()

        #expect(state.value.replays.isEmpty)
    }
}
