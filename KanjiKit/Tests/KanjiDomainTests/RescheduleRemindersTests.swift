import Foundation
import Testing

@testable import KanjiDomain

private final class FakeScheduler: ReminderScheduling {
    var notifications: [PlannedNotification] = []
    var isPassive = false
    var cancelledAll = false

    func replacePending(with notifications: [PlannedNotification], isPassive: Bool) async {
        self.notifications = notifications
        self.isPassive = isPassive
    }

    func cancelAll() async {
        cancelledAll = true
        notifications = []
    }
}

private final class FakeAuthorizer: NotificationAuthorizing {
    var status: NotificationAuthorization
    init(_ status: NotificationAuthorization) { self.status = status }
    func authorizationStatus() async -> NotificationAuthorization { status }
    func requestAuthorization() async -> Bool { status == .authorized }
}

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
        scheduler: FakeScheduler = FakeScheduler(),
        authorization: FakeAuthorizer = FakeAuthorizer(.authorized)
    ) -> (RescheduleReminders, InMemoryStore<ReminderState>, FakeScheduler) {
        let useCase = RescheduleReminders(
            deck: deck,
            settings: InMemoryStore(settings),
            state: state,
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

    /// Il motivo per cui la coda precedente viene salvata: rischedulare due volte
    /// di fila non deve consumare 128 kanji.
    @Test func reschedulingTwiceDoesNotBurnTheDeck() async {
        let deck = makeDeck()
        let (useCase, state, _) = makeUseCase(deck: deck)

        await useCase.execute()
        let afterFirst = state.value.cycle.position
        await useCase.execute()

        #expect(afterFirst == ReminderPlanner.systemLimit)
        #expect(state.value.cycle.position == afterFirst)
    }

    @Test func carriesTheDiscreetModeToTheScheduler() async {
        var passive = ReminderSettings.default
        passive.isPassive = true
        let (useCase, _, scheduler) = makeUseCase(deck: makeDeck(), settings: passive)

        await useCase.execute()

        #expect(scheduler.isPassive)
    }

    @Test func anEmptyDeckSchedulesNothing() async {
        let (useCase, _, scheduler) = makeUseCase(deck: KanjiDeck(viewBox: 109, attribution: "", kanji: []))

        #expect(await useCase.execute() == .emptyDeck)
        #expect(scheduler.notifications.isEmpty)
    }
}
