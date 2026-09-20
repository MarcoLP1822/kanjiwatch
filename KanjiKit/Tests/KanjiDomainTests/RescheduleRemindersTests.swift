import Foundation
import Testing

@testable import KanjiDomain

@Suite("Rischedulazione")
struct RescheduleRemindersTests {
    private func makeDeck(count: Int = 120) -> KanjiDeck {
        let kanji = (1...max(count, 1)).map { index in
            Kanji(
                character: String(UnicodeScalar(0x4E00 + index)!),
                codepoint: String(format: "%05x", 0x4E00 + index),
                strokes: ["M0,0"],
                onReadings: [],
                kunReadings: [],
                meanings: ["placeholder"]
            )
        }
        return KanjiDeck(viewBox: 109, attribution: "", kanji: kanji)
    }

    private func makeUseCase(
        deck: KanjiDeck,
        settings: ReminderSettings = .default,
        state: InMemoryStore<ReminderState> = InMemoryStore(.empty),
        ambient: InMemoryStore<AmbientState> = InMemoryStore(.empty),
        scheduler: FakeScheduler = FakeScheduler(),
        authorization: FakeAuthorizer = FakeAuthorizer(.authorized)
    ) -> (RescheduleReminders, InMemoryStore<ReminderState>, FakeScheduler) {
        let useCase = RescheduleReminders(
            deck: deck,
            settings: InMemoryStore(settings),
            state: state,
            ambient: ambient,
            scheduler: scheduler,
            authorization: authorization,
            now: { date("2026-05-10 09:12") },
            calendar: calendar
        )
        return (useCase, state, scheduler)
    }

    @Test func fillsTheQueueAndRemembersIt() async {
        let deck = makeDeck()
        let (useCase, state, scheduler) = makeUseCase(deck: deck)

        let outcome = await useCase.execute()

        #expect(outcome == .scheduled(ReminderPlanner.systemLimit))
        #expect(scheduler.notifications.count == ReminderPlanner.systemLimit)
        #expect(state.value.scheduled.count == ReminderPlanner.systemLimit)
        // Il titolo della notifica è il carattere, e deve venire dal mazzo vero.
        let first = scheduler.notifications[0]
        #expect(deck[first.codepoint]?.character == first.character)
    }

    /// Senza permesso lo scheduler girerebbe a vuoto senza dire niente: meglio
    /// svuotare la coda e dirlo a chi ha chiamato.
    @Test func clearsTheQueueWhenThePermissionIsMissing() async {
        let (useCase, state, scheduler) = makeUseCase(
            deck: makeDeck(),
            authorization: FakeAuthorizer(.denied)
        )

        let outcome = await useCase.execute()

        #expect(outcome == .notAuthorized)
        #expect(scheduler.cancelledAll)
        #expect(scheduler.notifications.isEmpty)
        #expect(state.value.scheduled.isEmpty)
    }

    /// Rischedulare due volte di fila, senza che sia successo niente, deve dare la
    /// stessa coda: il piano si ricalcola, non si consuma.
    @Test func reschedulingTwiceGivesTheSameQueue() async {
        let (useCase, state, _) = makeUseCase(deck: makeDeck())

        await useCase.execute()
        let afterFirst = state.value.scheduled
        await useCase.execute()

        #expect(afterFirst.count == ReminderPlanner.systemLimit)
        #expect(state.value.scheduled == afterFirst)
    }

    @Test func carriesTheDiscreetModeToTheScheduler() async {
        var passive = ReminderSettings.default
        passive.isPassive = true
        let (useCase, _, scheduler) = makeUseCase(deck: makeDeck(), settings: passive)

        await useCase.execute()

        #expect(scheduler.isPassive)
    }

    /// Dopo un NEXT la coda riparte da quel momento, e i kanji già avuti oggi
    /// occupano posti del tetto giornaliero.
    @Test func nextAndTodaysKanjiShapeTheQueue() async {
        var settings = ReminderSettings.default
        settings.dailyLimit = 3
        let now = date("2026-05-10 09:12")
        let state = InMemoryStore(
            ReminderState(
                today: DailyCount(day: calendar.startOfDay(for: now), count: 2),
                anchor: date("2026-05-10 09:05")
            )
        )
        let (useCase, _, scheduler) = makeUseCase(deck: makeDeck(), settings: settings, state: state)

        await useCase.execute()

        #expect(
            scheduler.notifications.prefix(2).map { label($0.fireDate) } == ["2026-05-10 10:05", "2026-05-11 08:00"])
    }

    /// Un grado spento lascia in coda kanji che non ci sono più: vanno tolti, non
    /// rimandati a ogni rischedulazione.
    @Test func kanjiRemovedFromTheDeckLeaveTheQueue() async {
        let deck = makeDeck()
        let state = InMemoryStore(
            ReminderState(
                scheduled: [ScheduledReminder(fireDate: date("2026-05-10 10:00"), codepoint: "0ffff")]
            )
        )
        let (useCase, _, scheduler) = makeUseCase(deck: deck, state: state)

        await useCase.execute()

        #expect(!state.value.scheduled.contains { $0.codepoint == "0ffff" })
        #expect(scheduler.notifications.count == ReminderPlanner.systemLimit)
    }

    /// Senza permesso non arriverà niente: la schermata d'attesa non deve promettere orari.
    @Test func withoutPermissionNothingIsPromised() async {
        let state = InMemoryStore(
            ReminderState(
                scheduled: [ScheduledReminder(fireDate: date("2026-05-10 10:00"), codepoint: "04e01")]
            )
        )
        let (useCase, _, _) = makeUseCase(deck: makeDeck(), state: state, authorization: FakeAuthorizer(.denied))

        #expect(await useCase.execute() == .notAuthorized)
        #expect(state.value.scheduled.isEmpty)
    }

    @Test func anEmptyDeckSchedulesNothing() async {
        let (useCase, _, scheduler) = makeUseCase(deck: KanjiDeck(viewBox: 109, attribution: "", kanji: []))

        #expect(await useCase.execute() == .emptyDeck)
        #expect(scheduler.notifications.isEmpty)
    }
}
