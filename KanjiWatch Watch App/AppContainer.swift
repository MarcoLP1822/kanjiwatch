import Foundation
import KanjiData
import KanjiDomain
import KanjiPurchases
import PaywallFeature
import SettingsFeature
import StudyFeature
import WidgetKit

/// Il punto in cui le cose vengono messe insieme: l'unico che conosce sia il
/// dominio sia gli adattatori. Le feature ricevono quello che serve e non sanno
/// da dove arriva — è per questo che il target app non contiene altro che questo.
@MainActor
final class AppContainer {
    /// Il controller della notifica lo istanzia il sistema, non l'app: serve un
    /// punto d'accesso statico per arrivare al mazzo già caricato.
    static let shared = AppContainer()

    private static let lastKnownSubscriptionKey = "subscription.lastKnown"

    let catalog: DeckCatalog
    /// Il mazzo dei gradi che valgono adesso. Cambia quando nelle impostazioni si
    /// accende o si spegne un grado, o quando cambia l'abbonamento.
    private(set) var deck: KanjiDeck

    /// Pigri perché le loro callback devono poter vedere `self`, e dentro `init` non
    /// si può ancora.
    lazy var study: StudyViewModel = {
        let model = StudyViewModel(loop: makeStudyLoop())
        model.onAdvance = { [weak self] in self?.reschedule() }
        model.onReadingsFirstShown = { [weak self] in
            Task { await self?.askForPermissionIfNeverAsked() }
        }
        return model
    }()

    lazy var settings = SettingsViewModel(
        store: settingsStore,
        authorization: scheduler,
        levels: catalog.levels,
        subscription: subscription,
        onSettingsChanged: { [weak self] in await self?.settingsDidChange() }
    )

    private let repository: BundledDeckRepository
    private let settingsStore = UserDefaultsStore<ReminderSettings>.settings()
    private let stateStore = UserDefaultsStore<ReminderState>.reminderState()
    /// Lo storico delle esposizioni sta in un file suo: cresce con l'uso, e a
    /// differenza delle altre due chiavi non lo legge nessun altro.
    private let ambientStore = JSONFileStore<AmbientState>.ambientState()
    private let complicationStore = UserDefaultsStore<[GlanceEntry]>.complicationTimeline()
    private let subscriptionStore = UserDefaultsStore<SubscriptionStatus>(
        key: AppContainer.lastKnownSubscriptionKey,
        default: .free
    )
    private let scheduler = UserNotificationScheduler()
    private let subscriptions = AppContainer.makeSubscriptionGateway()
    private var subscription: SubscriptionStatus
    private var loadedGrades: Set<Int>
    private var lastReschedule: Task<Void, Never>?

    private init() {
        let repository = BundledDeckRepository()
        // Si parte dall'ultimo stato noto: un abbonato che apre l'app senza rete deve
        // ritrovare i suoi mazzi, non quelli gratuiti per un istante.
        let subscription = UserDefaultsStore<SubscriptionStatus>(
            key: AppContainer.lastKnownSubscriptionKey,
            default: .free
        ).load()
        let saved = UserDefaultsStore<ReminderSettings>.settings().load()
        var grades = AccessPolicy.effective(saved, for: subscription).grades

        let catalog: DeckCatalog
        var deck: KanjiDeck
        do {
            catalog = try repository.loadCatalog()
            // Solo i gradi che valgono: il mazzo gratuito si decodifica in una
            // frazione del tempo che servirebbe per tutti i 2.136 jōyō.
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
        self.subscription = subscription
        self.loadedGrades = grades
    }

    /// Senza chiave RevenueCat l'SDK non va nemmeno configurato: il negozio è quello di
    /// prova, così paywall e Premium si provano sul simulatore e su TestFlight senza
    /// addebiti.
    private static func makeSubscriptionGateway() -> any SubscriptionGateway {
        guard AppConfiguration.revenueCatAPIKey.isEmpty else {
            return RevenueCatSubscriptionGateway(apiKey: AppConfiguration.revenueCatAPIKey)
        }
        return SimulatedSubscriptionGateway()
    }

    /// All'avvio e a ogni ritorno in primo piano. È il ciclo che si autoalimenta:
    /// finché apri l'app, la coda resta piena.
    func becameActive() {
        // Le notifiche arrivate mentre eri via possono aver messo in gioco un altro kanji.
        study.refresh()
        reschedule()
        // L'abbonamento può essere scaduto, rinnovato o ripristinato altrove.
        Task { await subscriptionDidChange(await subscriptions.currentStatus()) }
    }

    /// Dalla notifica o dalla complication: apre sul kanji che hai guardato al polso,
    /// nella stessa forma in cui l'hai visto, e rimette in moto la coda.
    func open(_ destination: ReminderDestination) {
        study.open(destination)
        reschedule()
    }

    func makePaywall() -> PaywallViewModel {
        PaywallViewModel(
            gateway: subscriptions,
            onPremium: { [weak self] in
                Task { await self?.subscriptionDidChange(.premium) }
            }
        )
    }

    private func subscriptionDidChange(_ status: SubscriptionStatus) async {
        guard status != subscription else { return }
        subscription = status
        subscriptionStore.save(status)
        settings.updateSubscription(status)
        await settingsDidChange()
    }

    /// Se sono cambiati i gradi che valgono si ricarica solo quello che serve, poi
    /// si rifà la coda: le notifiche già programmate potrebbero mostrare kanji spenti.
    private func settingsDidChange() async {
        let wanted = effectiveSettings.load().grades
        if wanted != loadedGrades, let reloaded = try? repository.loadDeck(grades: wanted), !reloaded.isEmpty {
            deck = reloaded
            loadedGrades = wanted
            study.replace(loop: makeStudyLoop())
        }
        await rescheduleAndPublish()
    }

    private func reschedule() {
        Task { await rescheduleAndPublish() }
    }

    /// Rifà la coda, poi aggiorna schermata e quadrante, sempre in quest'ordine:
    /// notifica, app e complication devono dire la stessa cosa.
    ///
    /// Una alla volta: all'apertura da una notifica ne partono due insieme, e due
    /// code rifatte in parallelo mescolerebbero le loro notifiche.
    private func rescheduleAndPublish() async {
        let previous = lastReschedule
        let current = Task {
            await previous?.value
            await rescheduleReminders().execute()
            study.refresh()
            publishComplication()
        }
        lastReschedule = current
        await current.value
    }

    /// Sul quadrante il kanji in gioco, poi uno per ogni notifica in coda — ciascuno
    /// nella forma della notifica che lo porta.
    private func publishComplication() {
        let state = stateStore.load()
        complicationStore.save(
            ComplicationTimeline.entries(
                now: Date(),
                current: study.kanji,
                currentContent: state.session.content,
                currentReference: state.session.reference,
                upcoming: state.scheduled,
                deck: deck
            )
        )
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Col Premium il motore guarda anche come interagisci e dà a ogni kanji il suo
    /// ritmo. Senza, i segnali si raccolgono lo stesso ma non si usano: chi compra
    /// dopo due settimane d'uso trova un motore che lo conosce già.
    private var ambientMode: AmbientMode {
        subscription == .premium ? .adaptive : .standard
    }

    /// Lo scheduler legge le impostazioni effettive, ma le scelte dell'utente restano
    /// salvate intatte: al rinnovo tornano da sole.
    private var effectiveSettings: PolicyAppliedSettings {
        PolicyAppliedSettings(base: settingsStore, status: { [weak self] in self?.subscription ?? .free })
    }

    private func makeStudyLoop() -> StudyLoop {
        StudyLoop(
            deck: deck,
            settings: effectiveSettings,
            state: stateStore,
            ambient: ambientStore,
            mode: { [weak self] in self?.ambientMode ?? .standard }
        )
    }

    /// Costruito al momento e non tenuto da parte: è una struct da niente, e così
    /// usa sempre mazzo e abbonamento correnti.
    private func rescheduleReminders() -> RescheduleReminders {
        RescheduleReminders(
            deck: deck,
            settings: effectiveSettings,
            state: stateStore,
            ambient: ambientStore,
            mode: { [weak self] in self?.ambientMode ?? .standard },
            scheduler: scheduler,
            authorization: scheduler
        )
    }

    /// Solo la prima volta: se l'utente ha già detto di no, non si insiste.
    private func askForPermissionIfNeverAsked() async {
        guard await scheduler.authorizationStatus() == .notDetermined else { return }
        _ = await scheduler.requestAuthorization()
        await rescheduleAndPublish()
    }
}
