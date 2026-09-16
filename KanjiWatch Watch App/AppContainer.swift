import KanjiData
import KanjiDomain
import SettingsFeature
import StudyFeature

/// Il punto in cui le cose vengono messe insieme: l'unico che conosce sia il
/// dominio sia gli adattatori. Le feature ricevono quello che serve e non sanno
/// da dove arriva — è per questo che il target app non contiene altro che questo.
@MainActor
final class AppContainer {
    /// Il controller della notifica lo istanzia il sistema, non l'app: serve un
    /// punto d'accesso statico per arrivare al mazzo già caricato.
    static let shared = AppContainer()

    let catalog: DeckCatalog
    /// Il mazzo dei gradi attivi. Cambia quando nelle impostazioni si accende o si
    /// spegne un grado; la long look lo legge per trovare il kanji della notifica.
    private(set) var deck: KanjiDeck
    let study: StudyViewModel

    /// Pigra perché la sua callback deve poter vedere `self`, e dentro `init` non si
    /// può ancora.
    lazy var settings = SettingsViewModel(
        store: settingsStore,
        authorization: scheduler,
        levels: catalog.levels,
        onSettingsChanged: { [weak self] in await self?.settingsDidChange() }
    )

    private let repository: BundledDeckRepository
    private let settingsStore = UserDefaultsStore<ReminderSettings>.settings()
    private let stateStore = UserDefaultsStore<ReminderState>.reminderState()
    private let scheduler = UserNotificationScheduler()
    private var loadedGrades: Set<Int>

    private init() {
        let repository = BundledDeckRepository()
        var grades = UserDefaultsStore<ReminderSettings>.settings().load().grades
        let catalog: DeckCatalog
        var deck: KanjiDeck
        do {
            catalog = try repository.loadCatalog()
            // Solo i gradi attivi: il mazzo gratuito si decodifica in una frazione
            // del tempo che servirebbe per tutti i 2.136 jōyō.
            deck = try repository.loadDeck(grades: grades)
            if deck.isEmpty {
                // Gradi salvati che nel bundle non esistono più: si riparte dal
                // mazzo gratuito invece di aprire su una schermata vuota.
                grades = KanjiLevel.freeGrades
                deck = try repository.loadDeck(grades: grades)
            }
        } catch {
            // I file del mazzo stanno nel bundle: se mancano è rotta la build, non
            // l'app dell'utente. KanjiDataTests lo verifica a ogni giro.
            fatalError("mazzo non caricabile: \(error)")
        }

        self.repository = repository
        self.catalog = catalog
        self.deck = deck
        self.loadedGrades = grades
        study = StudyViewModel(deck: deck)

        study.onFirstDrawingCompleted = { [weak self] in
            Task { await self?.askForPermissionIfNeverAsked() }
        }
    }

    /// All'avvio, al ritorno in primo piano e quando si tocca una notifica:
    /// finché usi l'app la coda non si svuota mai.
    func reschedule() {
        Task { await rescheduleReminders().execute() }
    }

    /// Dalla notifica: apre sul kanji che hai guardato al polso e rimette in moto
    /// la coda.
    func open(codepoint: String) {
        study.show(codepoint: codepoint)
        reschedule()
    }

    /// Se sono cambiati i mazzi si ricarica solo quello che serve, poi si rifà la
    /// coda: le notifiche già programmate potrebbero mostrare kanji spenti.
    private func settingsDidChange() async {
        let wanted = settingsStore.load().grades
        if wanted != loadedGrades, let reloaded = try? repository.loadDeck(grades: wanted), !reloaded.isEmpty {
            deck = reloaded
            loadedGrades = wanted
            study.replaceDeck(reloaded)
        }
        await rescheduleReminders().execute()
    }

    /// Costruito al momento e non tenuto da parte: è una struct da niente, e così
    /// usa sempre il mazzo corrente.
    private func rescheduleReminders() -> RescheduleReminders {
        RescheduleReminders(
            deck: deck,
            settings: settingsStore,
            state: stateStore,
            scheduler: scheduler,
            authorization: scheduler
        )
    }

    /// Solo la prima volta: se l'utente ha già detto di no, non si insiste.
    private func askForPermissionIfNeverAsked() async {
        guard await scheduler.authorizationStatus() == .notDetermined else { return }
        _ = await scheduler.requestAuthorization()
        await rescheduleReminders().execute()
    }
}
