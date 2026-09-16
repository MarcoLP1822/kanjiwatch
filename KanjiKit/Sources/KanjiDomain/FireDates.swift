import Foundation

/// Gli orari delle notifiche.
///
/// Sono ancorati all'inizio della finestra attiva, non al momento in cui li chiedi.
/// Il motivo è pratico: l'app cancella e rischedula tutto a ogni apertura, e con
/// orari calcolati "da adesso" ogni sguardo all'app sposterebbe in avanti la
/// notifica successiva — aprendola ogni tanto, non arriverebbe mai. Ancorata alla
/// finestra, la griglia è la stessa a ogni ricalcolo.
public enum FireDates {

    /// Quanti giorni al massimo si guarda avanti prima di arrendersi: con 64
    /// notifiche ogni 4 ore sono due settimane abbondanti. Serve solo a non
    /// girare a vuoto se la finestra non contenesse nessuno slot.
    private static let maximumDaysScanned = 400

    public static func next(
        count: Int,
        after start: Date,
        everyMinutes: Int,
        activeHours: ActiveHours,
        calendar: Calendar = .current
    ) -> [Date] {
        guard count > 0, everyMinutes > 0 else { return [] }

        var dates: [Date] = []
        // Una finestra che attraversa la mezzanotte può essere cominciata ieri:
        // alle 01:00, con 22→6, lo slot buono appartiene alla finestra di ieri sera.
        let firstDay =
            activeHours.crossesMidnight
            ? calendar.date(byAdding: .day, value: -1, to: start) ?? start
            : start
        var day = calendar.startOfDay(for: firstDay)

        for _ in 0..<maximumDaysScanned {
            guard let window = window(startingOn: day, activeHours: activeHours, calendar: calendar) else {
                break
            }
            var slot = window.start
            while slot < window.end {
                if slot > start {
                    dates.append(slot)
                    if dates.count == count { return dates }
                }
                guard
                    let advanced = calendar.date(byAdding: .minute, value: everyMinutes, to: slot),
                    advanced > slot
                else { break }
                slot = advanced
            }
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = tomorrow
        }
        return dates
    }

    /// Inizio e fine (esclusa) della finestra che parte nel giorno indicato.
    /// Le ore si impostano con il calendario, non sommando secondi: nel giorno del
    /// cambio d'ora l'una non equivale all'altra.
    private static func window(
        startingOn day: Date,
        activeHours: ActiveHours,
        calendar: Calendar
    ) -> (start: Date, end: Date)? {
        guard let start = calendar.date(bySettingHour: activeHours.startHour, minute: 0, second: 0, of: day)
        else { return nil }

        let endDay =
            activeHours.crossesMidnight
            ? calendar.date(byAdding: .day, value: 1, to: day) ?? day
            : day
        guard var end = calendar.date(bySettingHour: activeHours.endHour, minute: 0, second: 0, of: endDay)
        else { return nil }

        // Inizio e fine coincidenti: la finestra è tutta la giornata.
        if end <= start {
            end = calendar.date(byAdding: .day, value: 1, to: end) ?? end
        }
        return (start, end)
    }
}
