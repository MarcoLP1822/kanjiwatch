import Foundation

/// Una notifica programmata: quando, e quale kanji.
public struct ScheduledReminder: Equatable, Sendable, Codable {
    public let fireDate: Date
    public let codepoint: String

    public init(fireDate: Date, codepoint: String) {
        self.fireDate = fireDate
        self.codepoint = codepoint
    }
}

/// Costruisce la coda delle notifiche.
///
/// I vincoli non sono scelte di design, sono di sistema: un'app può avere al
/// massimo 64 notifiche in attesa, e un trigger ripetuto mostrerebbe sempre lo
/// stesso contenuto — quindi servono N notifiche distinte, una per kanji.
public enum ReminderPlanner {
    /// Limite di sistema per app. Non aggirabile.
    public static let systemLimit = 64

    /// Le ultime quattro non seguono l'intervallo. Se smetti di aprire l'app la
    /// coda si esaurisce e l'app smette di esistere in silenzio: distanziate così,
    /// resta un promemoria di recupero anche dopo giorni di silenzio.
    public static let recoveryOffsetsInHours = [12, 24, 48, 96]

    public static func plan(
        now: Date,
        settings: ReminderSettings,
        previous: [ScheduledReminder] = [],
        cycle: inout DeckCycle,
        using generator: inout some RandomNumberGenerator,
        anchor: Date? = nil,
        usedToday: Int = 0,
        calendar: Calendar = .current
    ) -> [ScheduledReminder] {
        // I kanji già estratti per notifiche che non sono mai arrivate tornano in
        // testa alla coda: senza, ogni apertura dell'app ne brucerebbe 64, e la
        // garanzia "ognuno una volta prima di ripetersi" salterebbe.
        var unshown =
            previous
            .filter { $0.fireDate > now }
            .sorted { $0.fireDate < $1.fireDate }
            .map(\.codepoint)

        let dates = fireDates(now: now, settings: settings, anchor: anchor, usedToday: usedToday, calendar: calendar)
        var reminders: [ScheduledReminder] = []
        for fireDate in dates {
            guard let codepoint = unshown.isEmpty ? cycle.next(using: &generator) : unshown.removeFirst() else {
                break
            }
            reminders.append(ScheduledReminder(fireDate: fireDate, codepoint: codepoint))
        }
        return reminders
    }

    private static func fireDates(
        now: Date,
        settings: ReminderSettings,
        anchor: Date?,
        usedToday: Int,
        calendar: Calendar
    ) -> [Date] {
        var dates = FireDates.next(
            count: systemLimit - recoveryOffsetsInHours.count,
            after: now,
            everyMinutes: settings.intervalMinutes,
            activeHours: settings.activeHours,
            anchor: anchor,
            dailyLimit: settings.dailyLimit,
            usedToday: usedToday,
            calendar: calendar
        )
        guard let lastRegular = dates.last else { return dates }

        for offset in recoveryOffsetsInHours {
            guard let target = calendar.date(byAdding: .hour, value: offset, to: lastRegular) else { continue }
            // Il recupero cade comunque dentro la finestra attiva: un promemoria
            // alle 3 di notte è peggio di nessun promemoria.
            let snapped = FireDates.next(
                count: 1,
                after: target.addingTimeInterval(-1),
                everyMinutes: settings.intervalMinutes,
                activeHours: settings.activeHours,
                calendar: calendar
            )
            if let slot = snapped.first, !dates.contains(slot) {
                dates.append(slot)
            }
        }

        // Anche i promemoria di recupero rispettano il tetto del giorno in cui cadono.
        var tally = DailyTally(limit: settings.dailyLimit, today: now, usedToday: usedToday, calendar: calendar)
        return dates.sorted().filter { tally.admit($0) }
    }
}
