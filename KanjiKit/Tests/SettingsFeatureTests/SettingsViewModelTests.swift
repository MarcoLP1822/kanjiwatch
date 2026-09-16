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
    private func makeModel(
        store: InMemoryStore = InMemoryStore(),
        authorizer: FakeAuthorizer = FakeAuthorizer(.notDetermined),
        spy: RescheduleSpy = RescheduleSpy()
    ) -> SettingsViewModel {
        SettingsViewModel(
            store: store,
            authorization: authorizer,
            rescheduleDelay: .zero,
            onSettingsChanged: { spy.count += 1 }
        )
    }

    @Test func loadsWhatWasSavedWithoutCountingAsAChange() {
        let store = InMemoryStore(
            ReminderSettings(
                intervalMinutes: 90,
                activeHours: ActiveHours(startHour: 7, endHour: 23),
                isPassive: true
            )
        )
        let spy = RescheduleSpy()
        let model = makeModel(store: store, spy: spy)

        #expect(model.intervalMinutes == 90)
        #expect(model.startHour == 7)
        #expect(model.endHour == 23)
        #expect(model.isPassive)
        #expect(spy.count == 0)
    }

    @Test func savesEveryChangeImmediately() {
        let store = InMemoryStore()
        let model = makeModel(store: store)

        model.intervalMinutes = 30
        model.startHour = 9
        model.isPassive = true

        #expect(store.value.intervalMinutes == 30)
        #expect(store.value.activeHours.startHour == 9)
        #expect(store.value.isPassive)
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
