import Foundation

/// Quello che l'app deve ricordarsi tra un avvio e l'altro: a che punto è il giro
/// del mazzo, e cosa c'era in coda l'ultima volta.
///
/// La coda serve per sapere quali kanji erano già stati estratti ma non ancora
/// mostrati, quando si rischedula.
public struct ReminderState: Equatable, Sendable, Codable {
    public var cycle: DeckCycle
    public var scheduled: [ScheduledReminder]

    public init(cycle: DeckCycle, scheduled: [ScheduledReminder] = []) {
        self.cycle = cycle
        self.scheduled = scheduled
    }

    /// Primo avvio: nessun giro cominciato e nessuna coda. `reconcile` col mazzo
    /// del bundle lo riempie, così non serve un optional in giro per il codice.
    public static let empty = ReminderState(cycle: DeckCycle(order: [], position: 0))
}
