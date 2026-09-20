import Foundation

/// Non solo *quale* kanji, ma *come* mostrarlo.
///
/// Un kanji sconosciuto da solo non insegna niente — 議 senza significato è un
/// disegno — ma averci sempre il significato attaccato non fa mai scattare il
/// ricordo, e un kanji che non vedi mai dentro una parola resta una scheda.
/// Da qui le tre forme dello stesso incontro.
public enum ExposureContent: String, Equatable, Sendable, Codable, CaseIterable {
    /// Il kanji e il suo significato. La prima volta è sempre questa.
    case introduce
    /// Solo il kanji. Mezzo secondo per pensarci: il simbolo è già la domanda,
    /// scriverla sarebbe rumore su uno schermo di quella misura.
    case recall
    /// La parola che lo contiene, con lettura e significato: il kanji smette di
    /// essere un carattere e diventa lingua.
    case context
}

extension ExposureContent {
    /// Il giro dopo le prime tre volte: si torna a richiamare, ogni tanto si rivede
    /// dentro una parola, ogni tanto si rilegge il significato per intero.
    static let rhythm: [ExposureContent] = [.recall, .context, .recall, .introduce]

    /// Si ricava da quante volte il kanji è già comparso, e non si salva: un secondo
    /// contatore accanto a `presentationCount` sarebbe un secondo contatore da tenere
    /// allineato, cioè un modo per finire a mostrare "ricorda?" a chi quel kanji non
    /// l'ha mai visto.
    public static func forSightings(_ count: Int, hasWord: Bool) -> ExposureContent {
        let chosen: ExposureContent =
            switch count {
            case ..<1: .introduce
            case 1: .recall
            case 2: .context
            default: rhythm[(count - 3) % rhythm.count]
            }
        return chosen.resolved(hasWord: hasWord)
    }

    /// Senza una parola d'esempio non c'è nessun contesto da mostrare — JMdict non ne
    /// ha una per ogni kanji — e chi disegna la notifica e chi ne scrive il testo
    /// devono cadere sulla stessa alternativa.
    public func resolved(hasWord: Bool) -> ExposureContent {
        self == .context && !hasWord ? .introduce : self
    }
}
