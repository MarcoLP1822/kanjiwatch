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
    let study: StudyViewModel

    /// Pigra perché la sua callback deve poter vedere `self`, e dentro `init` non si
    /// può ancora.
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
    private let complicationStore = UserDefaultsStore<[GlanceEntry]>.complicationTimeline()
    private let subscriptionStore = UserDefaultsStore<SubscriptionStatus>(
        key: AppContainer.lastKnownSubscriptionKey,
        default: .free
    )
    private let scheduler = UserNotificationScheduler()
    private let subscriptions = AppContainer.makeSubscriptionGateway()
    private var subscription: SubscriptionStatus
    private var loadedGrades: Set<Int>

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
        study = StudyViewModel(deck: deck)

        study.onFirstDrawingCompleted = { [weak self] in
            Task { await self?.askForPermissionIfNeverAsked() }
        }
    }

    /// Senza chiave RevenueCat l'SDK non va nemmeno configurato: l'app gira gratuita.
    private static func makeSubscriptionGateway() -> any SubscriptionGateway {
        AppConfiguration.revenueCatAPIKey.isEmpty
            ? UnavailableSubscriptionGateway()
            : RevenueCatSubscriptionGateway(apiKey: AppConfiguration.revenueCatAPIKey)
    }

    /// All'avvio, al ritorno in primo piano e quando si tocca una notifica:
    /// finché usi l'app la coda non si svuota mai.
    func reschedule() {
        Task { await rescheduleAndPublish() }
    }

    /// All'avvio e al ritorno in primo piano: l'abbonamento può essere scaduto,
    /// rinnovato o ripristinato su un altro dispositivo.
    func refreshSubscription() {
        Task { await subscriptionDidChange(await subscriptions.currentStatus()) }
    }

    /// Dalla notifica o dalla complication: apre sul kanji che hai guardato al polso
    /// e rimette in moto la coda.
    func open(codepoint: String) {
        study.show(codepoint: codepoint)
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
            study.replaceDeck(reloaded)
        }
        await rescheduleAndPublish()
    }

    /// Rifà la coda e poi la timeline del quadrante, sempre insieme e in quest'ordine:
    /// notifica e complication devono mostrare lo stesso kanji.
    private func rescheduleAndPublish() async {
        let previous = stateStore.load()
        await rescheduleReminders().execute()
        publishComplication(previous: previous)
    }

    private func publishComplication(previous: ReminderState) {
        let now = Date()
        // Sul quadrante va l'ultimo kanji arrivato al polso; se non ne è ancora
        // arrivato nessuno, quello che l'app sta mostrando.
        let current = previous.lastDelivered(before: now).flatMap { deck[$0.codepoint] } ?? study.kanji
        complicationStore.save(
            ComplicationTimeline.entries(now: now, current: current, upcoming: stateStore.load().scheduled, deck: deck)
        )
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Lo scheduler legge le impostazioni effettive, ma le scelte dell'utente restano
    /// salvate intatte: al rinnovo tornano da sole.
    private var effectiveSettings: PolicyAppliedSettings {
        PolicyAppliedSettings(base: settingsStore, status: { [weak self] in self?.subscription ?? .free })
    }

    /// Costruito al momento e non tenuto da parte: è una struct da niente, e così
    /// usa sempre mazzo e abbonamento correnti.
    private func rescheduleReminders() -> RescheduleReminders {
        RescheduleReminders(
            deck: deck,
            settings: effectiveSettings,
            state: stateStore,
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
