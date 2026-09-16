import KanjiData
import KanjiDomain
import StudyFeature

/// Il punto in cui le cose vengono messe insieme: l'unico che conosce sia il
/// dominio sia gli adattatori. Le feature ricevono quello che serve e non sanno
/// da dove arriva — è per questo che il target app non contiene altro che questo.
@MainActor
final class AppContainer {
    /// Il controller della notifica lo istanzia il sistema, non l'app: serve un
    /// punto d'accesso statico per arrivare al mazzo già caricato.
    static let shared = AppContainer()

    let deck: KanjiDeck
    let study: StudyViewModel

    private let scheduler: UserNotificationScheduler
    private let reschedulePlan: RescheduleReminders

    private init() {
        let loaded: KanjiDeck
        do {
            loaded = try BundledDeckRepository().loadDeck()
        } catch {
            // kanji.json sta nel bundle: se manca è rotta la build, non l'app
            // dell'utente. Un test in KanjiDataTests lo verifica a ogni giro.
            fatalError("mazzo non caricabile: \(error)")
        }
        let notifications = UserNotificationScheduler()

        deck = loaded
        scheduler = notifications
        study = StudyViewModel(deck: loaded)
        reschedulePlan = RescheduleReminders(
            deck: loaded,
            settings: UserDefaultsStore<ReminderSettings>.settings(),
            state: UserDefaultsStore<ReminderState>.reminderState(),
            scheduler: notifications,
            authorization: notifications
        )

        study.onFirstDrawingCompleted = { [weak self] in
            Task { await self?.askForPermissionIfNeverAsked() }
        }
    }

    /// All'avvio, al ritorno in primo piano e quando si tocca una notifica:
    /// finché usi l'app la coda non si svuota mai.
    func reschedule() {
        Task { await reschedulePlan.execute() }
    }

    /// Dalla notifica: apre sul kanji che hai guardato al polso e rimette in moto
    /// la coda.
    func open(codepoint: String) {
        study.show(codepoint: codepoint)
        reschedule()
    }

    /// Solo la prima volta: se l'utente ha già detto di no, non si insiste.
    private func askForPermissionIfNeverAsked() async {
        guard await scheduler.authorizationStatus() == .notDetermined else { return }
        _ = await scheduler.requestAuthorization()
        await reschedulePlan.execute()
    }
}
