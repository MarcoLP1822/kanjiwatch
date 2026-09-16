import Foundation

/// Rifà la coda delle notifiche da zero.
///
/// Si chiama in tre punti: all'avvio, al ritorno in primo piano e quando si tocca
/// una notifica. Finché usi l'app la coda non si svuota mai — ed è per questo che
/// il ciclo si autoalimenta.
public struct RescheduleReminders {
    public enum Outcome: Equatable, Sendable {
        case scheduled(Int)
        /// Senza permesso lo scheduler girerebbe a vuoto: meglio saperlo e dirlo.
        case notAuthorized
        case emptyDeck
    }

    private let deck: KanjiDeck
    private let settings: any ValueStore<ReminderSettings>
    private let state: any ValueStore<ReminderState>
    private let scheduler: any ReminderScheduling
    private let authorization: any NotificationAuthorizing
    private let now: () -> Date
    private let calendar: Calendar

    public init(
        deck: KanjiDeck,
        settings: any ValueStore<ReminderSettings>,
        state: any ValueStore<ReminderState>,
        scheduler: any ReminderScheduling,
        authorization: any NotificationAuthorizing,
        now: @escaping () -> Date = Date.init,
        calendar: Calendar = .current
    ) {
        self.deck = deck
        self.settings = settings
        self.state = state
        self.scheduler = scheduler
        self.authorization = authorization
        self.now = now
        self.calendar = calendar
    }

    @discardableResult
    public func execute() async -> Outcome {
        guard await authorization.authorizationStatus() == .authorized else {
            await scheduler.cancelAll()
            return .notAuthorized
        }

        let preferences = settings.load()
        var current = state.load()
        var generator = SystemRandomNumberGenerator()
        // Un aggiornamento dell'app può aver cambiato il mazzo sotto il ciclo.
        current.cycle.reconcile(with: deck.codepoints, using: &generator)

        let reminders = ReminderPlanner.plan(
            now: now(),
            settings: preferences,
            previous: current.scheduled,
            cycle: &current.cycle,
            using: &generator,
            calendar: calendar
        )
        guard !reminders.isEmpty else { return .emptyDeck }

        let notifications = reminders.compactMap { reminder in
            deck[reminder.codepoint].map {
                PlannedNotification(fireDate: reminder.fireDate, codepoint: $0.codepoint, character: $0.character)
            }
        }
        await scheduler.replacePending(with: notifications, isPassive: preferences.isPassive)

        current.scheduled = reminders
        state.save(current)
        return .scheduled(reminders.count)
    }
}
