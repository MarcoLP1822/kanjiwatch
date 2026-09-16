import Foundation
import Testing

@testable import KanjiDomain

/// Qui si rompe tutto: mezzanotte, cambio d'ora, intervalli più larghi della
/// finestra. Fuso fisso a Roma, così i test non cambiano risultato con la macchina.
@Suite("Orari delle notifiche")
struct FireDatesTests {
    private let day = ActiveHours(startHour: 8, endHour: 22)
    private let night = ActiveHours(startHour: 22, endHour: 6)

    @Test func alignsToTheStartOfTheWindow() {
        let dates = FireDates.next(
            count: 3, after: date("2026-05-10 09:12"), everyMinutes: 60,
            activeHours: day, calendar: calendar
        )
        #expect(dates.map(label) == ["2026-05-10 10:00", "2026-05-10 11:00", "2026-05-10 12:00"])
    }

    @Test func jumpsOverTheQuietHours() {
        let dates = FireDates.next(
            count: 2, after: date("2026-05-10 21:30"), everyMinutes: 60,
            activeHours: day, calendar: calendar
        )
        #expect(dates.map(label) == ["2026-05-11 08:00", "2026-05-11 09:00"])
    }

    /// La finestra 22→6 non si può scrivere come ClosedRange, ed è il caso in cui
    /// una versione ingenua salta tutta la notte.
    @Test func handlesAWindowThatCrossesMidnight() {
        let dates = FireDates.next(
            count: 3, after: date("2026-05-10 23:10"), everyMinutes: 60,
            activeHours: night, calendar: calendar
        )
        #expect(dates.map(label) == ["2026-05-11 00:00", "2026-05-11 01:00", "2026-05-11 02:00"])
    }

    @Test func givesOneSlotADayWhenTheIntervalIsWiderThanTheWindow() {
        let dates = FireDates.next(
            count: 2, after: date("2026-05-10 07:00"), everyMinutes: 600,
            activeHours: ActiveHours(startHour: 8, endHour: 12), calendar: calendar
        )
        #expect(dates.map(label) == ["2026-05-10 08:00", "2026-05-11 08:00"])
    }

    /// Il motivo per cui gli orari sono ancorati: ricalcolare più tardi non deve
    /// spostare in avanti gli orari già previsti.
    @Test func reschedulingLaterKeepsTheSameGrid() {
        let first = FireDates.next(
            count: 6, after: date("2026-05-10 09:12"), everyMinutes: 90,
            activeHours: day, calendar: calendar
        )
        let afterTwo = FireDates.next(
            count: 4, after: first[1].addingTimeInterval(1), everyMinutes: 90,
            activeHours: day, calendar: calendar
        )
        #expect(afterTwo == Array(first.dropFirst(2)))
    }

    @Test func staysInsideTheWindowAcrossTheSpringClockChange() {
        // In Italia il 2026-03-29 le 02:00 diventano le 03:00.
        let dates = FireDates.next(
            count: 40, after: date("2026-03-28 20:00"), everyMinutes: 60,
            activeHours: day, calendar: calendar
        )
        for value in dates {
            #expect(day.contains(hour: calendar.component(.hour, from: value)), "fuori finestra: \(label(value))")
        }
        #expect(dates == dates.sorted())
        #expect(Set(dates).count == dates.count)
    }

    @Test func doesNotRepeatATimestampWhenTheClockGoesBack() {
        // Il 2026-10-25 le 03:00 tornano le 02:00: quell'ora esiste due volte.
        let dates = FireDates.next(
            count: 30, after: date("2026-10-24 20:00"), everyMinutes: 60,
            activeHours: night, calendar: calendar
        )
        #expect(Set(dates).count == dates.count)
        #expect(dates == dates.sorted())
    }

    @Test func refusesNonsense() {
        #expect(FireDates.next(count: 0, after: .now, everyMinutes: 60, activeHours: day, calendar: calendar).isEmpty)
        #expect(FireDates.next(count: 5, after: .now, everyMinutes: 0, activeHours: day, calendar: calendar).isEmpty)
    }
}
