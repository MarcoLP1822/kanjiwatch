import Foundation

/// Rifà la coda delle notifiche da zero.
///
/// Si chiama all'avvio, al ritorno in primo piano, quando si tocca una notifica e
/// dopo ogni NEXT. Finché usi l'app la coda non si svuota mai — ed è per questo che
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
        let isAuthorized = await authorization.authorizationStatus() == .authorized

        // Tra lettura e salvataggio dello stato non c'è nessun `await`: un NEXT
        // premuto mentre la coda si rifà non può finire sovrascritto.
        let moment = now()
        let preferences = settings.load()
        var current = state.load()
        var generator = SystemRandomNumberGenerator()
        // Le notifiche già arrivate contano nella giornata prima di rifare la coda,
        // altrimenti il tetto giornaliero non saprebbe quante ne sono passate.
        current.catchUp(with: deck, now: moment, using: &generator, calendar: calendar)

        guard isAuthorized else {
            // Non arriverà niente: la schermata d'attesa non deve promettere un orario.
            current.scheduled = []
            state.save(current)
            await scheduler.cancelAll()
            return .notAuthorized
        }

        let reminders = ReminderPlanner.plan(
            now: moment,
            settings: preferences,
            previous: current.scheduled,
            cycle: &current.cycle,
            using: &generator,
            anchor: current.anchor,
            usedToday: current.today.count(on: moment, calendar: calendar),
            calendar: calendar
        )
        current.scheduled = reminders
        state.save(current)
        guard !reminders.isEmpty else { return .emptyDeck }

        let notifications = reminders.compactMap { reminder in
            deck[reminder.codepoint].map {
                PlannedNotification(fireDate: reminder.fireDate, codepoint: $0.codepoint, character: $0.character)
            }
        }
        await scheduler.replacePending(with: notifications, isPassive: preferences.isPassive)
        return .scheduled(reminders.count)
    }
}
