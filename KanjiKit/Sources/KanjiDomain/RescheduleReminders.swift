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
    private let ambient: any ValueStore<AmbientState>
    private let mode: () -> AmbientMode
    private let scheduler: any ReminderScheduling
    private let authorization: any NotificationAuthorizing
    private let now: () -> Date
    private let calendar: Calendar

    public init(
        deck: KanjiDeck,
        settings: any ValueStore<ReminderSettings>,
        state: any ValueStore<ReminderState>,
        ambient: any ValueStore<AmbientState>,
        mode: @escaping () -> AmbientMode = { .standard },
        scheduler: any ReminderScheduling,
        authorization: any NotificationAuthorizing,
        now: @escaping () -> Date = Date.init,
        calendar: Calendar = .current
    ) {
        self.deck = deck
        self.settings = settings
        self.state = state
        self.ambient = ambient
        self.mode = mode
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
        var exposure = ambient.load()
        // Le notifiche già arrivate contano nella giornata prima di rifare la coda,
        // altrimenti il tetto giornaliero non saprebbe quante ne sono passate — e il
        // motore non saprebbe quali kanji ti sono già passati davanti.
        current.catchUp(with: deck, now: moment, ambient: &exposure, calendar: calendar)

        guard isAuthorized else {
            // Non arriverà niente: la schermata d'attesa non deve promettere un orario.
            current.scheduled = []
            state.save(current)
            ambient.save(exposure)
            await scheduler.cancelAll()
            return .notAuthorized
        }

        let reminders = ReminderPlanner.plan(
            now: moment,
            settings: preferences,
            deck: deck,
            ambient: exposure,
            currentCodepoint: current.session.codepoint,
            mode: mode(),
            anchor: current.anchor,
            usedToday: current.today.count(on: moment, calendar: calendar),
            calendar: calendar
        )
        current.scheduled = reminders
        state.save(current)
        ambient.save(exposure)
        guard !reminders.isEmpty else { return .emptyDeck }

        let notifications = reminders.compactMap { reminder in
            deck[reminder.codepoint].map {
                PlannedNotification(fireDate: reminder.fireDate, kanji: $0, content: reminder.content)
            }
        }
        await scheduler.replacePending(with: notifications, isPassive: preferences.isPassive)
        return .scheduled(reminders.count)
    }
}
