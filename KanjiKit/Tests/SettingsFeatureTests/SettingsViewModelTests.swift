import Foundation
import KanjiDomain
import Testing

@testable import SettingsFeature

private final class FakeAuthorizer: NotificationAuthorizing {
    var status: NotificationAuthorization
    var requested = false
    init(_ status: NotificationAuthorization) { self.status = status }
    func authorizationStatus() async -> NotificationAuthorization { status }
    func requestAuthorization() async -> Bool {
        requested = true
        status = .authorized
        return true
    }
}

private final class RescheduleSpy {
    var count = 0
}

@Suite("Impostazioni")
@MainActor
struct SettingsViewModelTests {
    private let levels = [
        KanjiLevel(grade: 1, count: 80),
        KanjiLevel(grade: 2, count: 160),
        KanjiLevel(grade: 3, count: 200),
    ]

    private func makeModel(
        store: InMemoryStore<ReminderSettings> = InMemoryStore(.default),
        authorizer: FakeAuthorizer = FakeAuthorizer(.notDetermined),
        subscription: SubscriptionStatus = .premium,
        spy: RescheduleSpy = RescheduleSpy()
    ) -> SettingsViewModel {
        SettingsViewModel(
            store: store,
            authorization: authorizer,
            levels: levels,
            subscription: subscription,
            rescheduleDelay: .zero,
            onSettingsChanged: { spy.count += 1 }
        )
    }

    @Test func loadsWhatWasSavedWithoutCountingAsAChange() {
        let store = InMemoryStore(
            ReminderSettings(
                intervalMinutes: 90,
                activeHours: ActiveHours(startHour: 7, endHour: 23),
                isPassive: true,
                grades: [2, 3],
                dailyLimit: 20
            )
        )
        let spy = RescheduleSpy()
        let model = makeModel(store: store, spy: spy)

        #expect(model.intervalMinutes == 90)
        #expect(model.startHour == 7)
        #expect(model.endHour == 23)
        #expect(model.isPassive)
        #expect(model.grades == [2, 3])
        #expect(model.dailyLimit == 20)
        #expect(spy.count == 0)
    }

    @Test func savesEveryChangeImmediately() {
        let store = InMemoryStore(ReminderSettings.default)
        let model = makeModel(store: store)

        model.intervalMinutes = 30
        model.startHour = 9
        model.isPassive = true
        model.dailyLimit = 5
        model.setGrade(3, enabled: true)

        #expect(store.value.intervalMinutes == 30)
        #expect(store.value.activeHours.startHour == 9)
        #expect(store.value.isPassive)
        #expect(store.value.dailyLimit == 5)
        #expect(store.value.grades == [1, 2, 3])
    }

    /// Un'app di ripasso senza niente da ripassare è solo un'app rotta.
    @Test func refusesToTurnOffTheLastDeck() {
        var onlyFirst = ReminderSettings.default
        onlyFirst.grades = [1]
        let store = InMemoryStore(onlyFirst)
        let model = makeModel(store: store)

        model.setGrade(1, enabled: false)

        #expect(model.grades == [1])
        #expect(store.value.grades == [1])
    }

    @Test func aFreeUserCannotTurnOnAPaidDeck() {
        let store = InMemoryStore(ReminderSettings.default)
        let model = makeModel(store: store, subscription: .free)

        model.setGrade(3, enabled: true)

        #expect(model.isLocked(levels[2]))
        #expect(!model.isLocked(levels[0]))
        #expect(model.grades == KanjiLevel.freeGrades)
        #expect(store.value.grades == KanjiLevel.freeGrades)
    }

    /// Chi non è abbonato vede il ritmo che vale davvero, non quello che aveva scelto.
    @Test func aFreeUserSeesTheEffectiveRhythm() {
        var chosen = ReminderSettings.default
        chosen.intervalMinutes = 30
        chosen.dailyLimit = 30
        let model = makeModel(store: InMemoryStore(chosen), subscription: .free)

        #expect(model.effective.intervalMinutes == AccessPolicy.freeIntervalMinutes)
        #expect(model.effective.dailyLimit == AccessPolicy.freeDailyLimit)
    }

    @Test func subscribingUnlocksThePaidDecks() {
        let model = makeModel(subscription: .free)

        model.updateSubscription(.premium)
        model.setGrade(3, enabled: true)

        #expect(model.isPremium)
        #expect(model.grades.contains(3))
    }

    /// Con la corona i valori cambiano a raffica: la rischedulazione deve arrivare
    /// una volta sola, alla fine, non a ogni scatto.
    @Test func reschedulesOnceAfterABurstOfChanges() async {
        let spy = RescheduleSpy()
        let model = makeModel(spy: spy)

        model.intervalMinutes = 30
        model.intervalMinutes = 45
        model.intervalMinutes = 60
        // Si aspetta l'ultimo task, non un tempo fisso: i primi due sono stati
        // cancellati, e questo è il solo che deve arrivare in fondo.
        await model.pendingReschedule?.value

        #expect(spy.count == 1)
        #expect(model.intervalMinutes == 60)
    }

    @Test func readsTheAuthorizationBackFromTheSystem() async {
        let authorizer = FakeAuthorizer(.denied)
        let model = makeModel(authorizer: authorizer)

        await model.refreshAuthorization()

        #expect(model.authorization == .denied)
    }

    @Test func askingForThePermissionRebuildsTheQueue() async {
        let authorizer = FakeAuthorizer(.notDetermined)
        let spy = RescheduleSpy()
        let model = makeModel(authorizer: authorizer, spy: spy)

        await model.requestAuthorization()

        #expect(authorizer.requested)
        #expect(model.authorization == .authorized)
        #expect(spy.count == 1)
    }
}
