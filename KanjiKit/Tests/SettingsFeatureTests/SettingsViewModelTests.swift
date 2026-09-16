import Foundation
import KanjiDomain
import Testing

@testable import SettingsFeature

private final class InMemoryStore: ValueStore {
    var value: ReminderSettings
    init(_ value: ReminderSettings = .default) { self.value = value }
    func load() -> ReminderSettings { value }
    func save(_ value: ReminderSettings) { self.value = value }
}

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
        store: InMemoryStore = InMemoryStore(),
        authorizer: FakeAuthorizer = FakeAuthorizer(.notDetermined),
        spy: RescheduleSpy = RescheduleSpy()
    ) -> SettingsViewModel {
        SettingsViewModel(
            store: store,
            authorization: authorizer,
            levels: levels,
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
                grades: [2, 3]
            )
        )
        let spy = RescheduleSpy()
        let model = makeModel(store: store, spy: spy)

        #expect(model.intervalMinutes == 90)
        #expect(model.startHour == 7)
        #expect(model.endHour == 23)
        #expect(model.isPassive)
        #expect(model.grades == [2, 3])
        #expect(spy.count == 0)
    }

    @Test func savesEveryChangeImmediately() {
        let store = InMemoryStore()
        let model = makeModel(store: store)

        model.intervalMinutes = 30
        model.startHour = 9
        model.isPassive = true
        model.setGrade(3, enabled: true)

        #expect(store.value.intervalMinutes == 30)
        #expect(store.value.activeHours.startHour == 9)
        #expect(store.value.isPassive)
        #expect(store.value.grades == [1, 2, 3])
    }

    /// Un'app di ripasso senza niente da ripassare è solo un'app rotta.
    @Test func refusesToTurnOffTheLastDeck() {
        let store = InMemoryStore(
            ReminderSettings(
                intervalMinutes: 60, activeHours: ActiveHours(startHour: 8, endHour: 22), isPassive: false, grades: [1]
            ))
        let model = makeModel(store: store)

        model.setGrade(1, enabled: false)

        #expect(model.grades == [1])
        #expect(store.value.grades == [1])
    }

    /// Con la corona i valori cambiano a raffica: la rischedulazione deve arrivare
    /// una volta sola, alla fine, non a ogni scatto.
    @Test func reschedulesOnceAfterABurstOfChanges() async throws {
        let spy = RescheduleSpy()
        let model = makeModel(spy: spy)

        model.intervalMinutes = 30
        model.intervalMinutes = 45
        model.intervalMinutes = 60
        try await Task.sleep(for: .milliseconds(120))

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
