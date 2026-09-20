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
    private let deck = testDeck(count: 200)

    private func plan(
        now: String,
        ambient: AmbientState = .empty,
        deck: KanjiDeck? = nil,
        currentCodepoint: String? = nil
    ) -> [ScheduledReminder] {
        ReminderPlanner.plan(
            now: date(now),
            settings: settings,
            deck: deck ?? self.deck,
            ambient: ambient,
            currentCodepoint: currentCodepoint,
            calendar: calendar
        )
    }

    @Test func fillsTheQueueUpToTheSystemLimit() {
        let reminders = plan(now: "2026-05-10 09:12")
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
        let reminders = plan(now: "2026-05-10 09:12")
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

    /// Non serve più riusare i kanji delle notifiche mai arrivate: a parità di
    /// storico la coda è identica, quindi rischedulare non consuma niente.
    @Test func reschedulingTwiceGivesTheSameQueue() {
        #expect(plan(now: "2026-05-10 09:12") == plan(now: "2026-05-10 09:12"))
    }

    /// Ma se nel frattempo hai incontrato qualcosa, il piano cambia.
    @Test func aSightingChangesTheQueue() {
        var ambient = AmbientState.empty
        ambient.record(.presented, codepoint: testCodepoint(5), at: date("2026-05-10 09:00"))

        #expect(plan(now: "2026-05-10 09:12", ambient: ambient) != plan(now: "2026-05-10 09:12"))
    }

    @Test func theFirstReminderIsNotTheKanjiOnScreen() {
        let onScreen = testCodepoint(0)
        #expect(plan(now: "2026-05-10 09:12", currentCodepoint: onScreen).first?.codepoint != onScreen)
    }

    @Test func anEmptyDeckGivesNoReminders() {
        #expect(plan(now: "2026-05-10 09:12", deck: testDeck(count: 0)).isEmpty)
    }
}
