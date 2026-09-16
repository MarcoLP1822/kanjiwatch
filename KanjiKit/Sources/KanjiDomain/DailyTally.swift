import Foundation

/// Quanti kanji ha già ogni giorno di calendario, rispetto al tetto giornaliero.
///
/// Lo usano sia il calcolo degli orari sia il planner: il tetto si conta in un modo
/// solo, qui.
struct DailyTally {
    private var counts: [Date: Int]
    private let limit: Int?
    private let calendar: Calendar

    /// `usedToday` sono i kanji che la giornata di `today` ha già avuto prima di
    /// questo calcolo: notifiche arrivate e NEXT.
    init(limit: Int?, today: Date, usedToday: Int, calendar: Calendar) {
        self.counts = [calendar.startOfDay(for: today): usedToday]
        self.limit = limit
        self.calendar = calendar
    }

    /// Vero se il giorno di `date` ha ancora posto; in quel caso il posto è preso.
    mutating func admit(_ date: Date) -> Bool {
        let day = calendar.startOfDay(for: date)
        guard counts[day, default: 0] < (limit ?? .max) else { return false }
        counts[day, default: 0] += 1
        return true
    }
}
