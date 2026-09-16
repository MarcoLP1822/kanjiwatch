import Foundation
import Testing

@testable import KanjiDomain

@Suite("Coda delle notifiche")
struct ReminderPlannerTests {
    private let settings = ReminderSettings(
        intervalMinutes: 60,
        activeHours: ActiveHours(startHour: 8, endHour: 22),
        isPassive: false
    )
    private let deck = (1...200).map { String(format: "%05x", $0) }

    private func plan(
        now: String,
        previous: [ScheduledReminder] = [],
        deck: [String]? = nil
    ) -> (reminders: [ScheduledReminder], cycle: DeckCycle) {
        var generator = SeededGenerator(seed: 11)
        var cycle = DeckCycle(codepoints: deck ?? self.deck, using: &generator)
        let reminders = ReminderPlanner.plan(
            now: date(now),
            settings: settings,
            previous: previous,
            cycle: &cycle,
            using: &generator,
            calendar: calendar
        )
        return (reminders, cycle)
    }

    @Test func fillsTheQueueUpToTheSystemLimit() {
        let (reminders, _) = plan(now: "2026-05-10 09:12")
        #expect(reminders.count == ReminderPlanner.systemLimit)
        #expect(reminders.map(\.fireDate) == reminders.map(\.fireDate).sorted())
        #expect(Set(reminders.map(\.fireDate)).count == reminders.count)
        for reminder in reminders {
            let hour = calendar.component(.hour, from: reminder.fireDate)
            #expect(settings.activeHours.contains(hour: hour), "fuori finestra: \(label(reminder.fireDate))")
        }
    }

    /// Il caso "la ignoro per due giorni": senza le ultime quattro, la coda si
    /// esaurisce e l'app sparisce.
    @Test func keepsRecoveryRemindersAtTheEnd() {
        let (reminders, _) = plan(now: "2026-05-10 09:12")
        let regular = reminders.prefix(ReminderPlanner.systemLimit - ReminderPlanner.recoveryOffsetsInHours.count)
        let recovery = reminders.suffix(ReminderPlanner.recoveryOffsetsInHours.count)
        let lastRegular = regular.last!.fireDate

        #expect(recovery.first!.fireDate >= lastRegular.addingTimeInterval(12 * 3600))
        #expect(recovery.last!.fireDate >= lastRegular.addingTimeInterval(96 * 3600))
        for reminder in recovery {
            let hour = calendar.component(.hour, from: reminder.fireDate)
            #expect(settings.activeHours.contains(hour: hour))
        }
    }

    /// Il punto per cui esiste `previous`: rischedulare non deve bruciare il mazzo.
    @Test func reusesKanjiFromNotificationsThatNeverArrived() {
        let pending = [
            ScheduledReminder(fireDate: date("2026-05-10 10:00"), codepoint: "aaaaa"),
            ScheduledReminder(fireDate: date("2026-05-10 11:00"), codepoint: "bbbbb"),
            ScheduledReminder(fireDate: date("2026-05-10 12:00"), codepoint: "ccccc"),
        ]
        let (reminders, cycle) = plan(now: "2026-05-10 09:12", previous: pending)

        #expect(reminders.prefix(3).map(\.codepoint) == ["aaaaa", "bbbbb", "ccccc"])
        // Tre riusati, quindi dal mazzo ne sono usciti 64 - 3.
        #expect(cycle.position == ReminderPlanner.systemLimit - 3)
    }

    @Test func doesNotReuseKanjiThatWereAlreadyShown() {
        let alreadyFired = [
            ScheduledReminder(fireDate: date("2026-05-10 08:00"), codepoint: "aaaaa"),
            ScheduledReminder(fireDate: date("2026-05-10 09:00"), codepoint: "bbbbb"),
        ]
        let (reminders, cycle) = plan(now: "2026-05-10 09:12", previous: alreadyFired)

        #expect(!reminders.map(\.codepoint).contains("aaaaa"))
        #expect(cycle.position == ReminderPlanner.systemLimit)
    }

    @Test func anEmptyDeckGivesNoReminders() {
        let (reminders, _) = plan(now: "2026-05-10 09:12", deck: [])
        #expect(reminders.isEmpty)
    }
}
