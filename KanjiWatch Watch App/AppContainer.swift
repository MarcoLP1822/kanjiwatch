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

    private init() {
        do {
            deck = try BundledDeckRepository().loadDeck()
        } catch {
            // kanji.json sta nel bundle: se manca è rotta la build, non l'app
            // dell'utente. Un test in KanjiDataTests lo verifica a ogni giro.
            fatalError("mazzo non caricabile: \(error)")
        }
        study = StudyViewModel(deck: deck)
    }
}
