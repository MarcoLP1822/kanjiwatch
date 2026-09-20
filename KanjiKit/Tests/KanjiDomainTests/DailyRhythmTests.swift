import Foundation
import Testing

@testable import KanjiDomain

/// Il ritmo della giornata: l'intervallo, il tetto e la ripartenza dopo NEXT.
@Suite("Ritmo giornaliero")
struct DailyRhythmTests {
    private let day = ActiveHours(startHour: 8, endHour: 22)

    @Test func stopsTheDayWhenTheLimitIsReached() {
        let dates = FireDates.next(
            count: 5, after: date("2026-05-10 07:00"), everyMinutes: 60,
            activeHours: day, dailyLimit: 3, calendar: calendar
        )
        #expect(
            dates.map(label) == [
                "2026-05-10 08:00", "2026-05-10 09:00", "2026-05-10 10:00",
                "2026-05-11 08:00", "2026-05-11 09:00",
            ])
    }

    /// Le notifiche già arrivate e i NEXT di oggi occupano posti del tetto di oggi.
    @Test func whatTheDayAlreadyHadCountsTowardTheLimit() {
        let dates = FireDates.next(
            count: 2, after: date("2026-05-10 09:12"), everyMinutes: 60,
            activeHours: day, dailyLimit: 3, usedToday: 2, calendar: calendar
        )
        #expect(dates.map(label) == ["2026-05-10 10:00", "2026-05-11 08:00"])
    }

    /// NEXT fa ripartire l'intervallo da quando l'hai premuto, ma solo per quel giorno.
    @Test func nextRestartsTheIntervalOnlyForItsOwnDay() {
        let pressed = date("2026-05-10 21:12")
        let dates = FireDates.next(
            count: 3, after: pressed, everyMinutes: 30,
            activeHours: day, anchor: pressed, calendar: calendar
        )
        #expect(dates.map(label) == ["2026-05-10 21:42", "2026-05-11 08:00", "2026-05-11 08:30"])
    }

    @Test func thePlannerKeepsTheQueueFullAcrossDaysWithALimit() {
        var settings = ReminderSettings.default
        settings.dailyLimit = 5

        let reminders = ReminderPlanner.plan(
            now: date("2026-05-10 07:00"),
            settings: settings,
            deck: testDeck(count: 200),
            ambient: .empty,
            calendar: calendar
        )

        let perDay = Dictionary(grouping: reminders) { calendar.startOfDay(for: $0.fireDate) }.mapValues(\.count)
        #expect(reminders.count > 5)
        #expect(perDay.values.allSatisfy { $0 <= 5 })
    }

    /// Impostazioni salvate prima del tetto: si tengono tutte, e il tetto prende il default.
    @Test func settingsSavedBeforeTheLimitKeepTheirValues() throws {
        let saved = #"{"intervalMinutes":90,"activeHours":{"startHour":7,"endHour":23},"isPassive":true,"grades":[1]}"#
        let settings = try JSONDecoder().decode(ReminderSettings.self, from: Data(saved.utf8))
        #expect(settings.intervalMinutes == 90)
        #expect(settings.grades == [1])
        #expect(settings.dailyLimit == ReminderSettings.defaultDailyLimit)
        #expect(settings.theme == .aiZome)
    }

    /// Un tema che nell'app non esiste più non deve far perdere le altre impostazioni.
    @Test func anUnknownThemeFallsBackWithoutLosingTheRest() throws {
        let saved =
            #"{"intervalMinutes":45,"activeHours":{"startHour":8,"endHour":22},"isPassive":false,"theme":"neon"}"#
        let settings = try JSONDecoder().decode(ReminderSettings.self, from: Data(saved.utf8))
        #expect(settings.intervalMinutes == 45)
        #expect(settings.theme == .aiZome)
    }

    @Test func freeUsersGetTheDefaultLimit() {
        var chosen = ReminderSettings.default
        chosen.dailyLimit = 30
        #expect(AccessPolicy.effective(chosen, for: .free).dailyLimit == ReminderSettings.defaultDailyLimit)
        #expect(AccessPolicy.effective(chosen, for: .premium).dailyLimit == 30)
    }
}
