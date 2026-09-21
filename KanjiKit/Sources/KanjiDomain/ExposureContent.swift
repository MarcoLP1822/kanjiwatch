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
    /// Il giro dopo le prime tre volte, a seconda di quanto quel kanji sembra
    /// chiedere un appiglio.
    ///
    /// Più supporto vuol dire più esposizioni che si portano dietro qualcosa —
    /// significato o parola — ma il richiamo resta sempre nel giro: trasformare
    /// tutto in risposte pronte vorrebbe dire non far più ricordare niente.
    static func rhythm(for support: SupportLevel) -> [ExposureContent] {
        switch support {
        case .low: [.recall, .context, .recall, .introduce]
        case .medium: [.context, .recall, .introduce, .recall]
        case .high: [.introduce, .context, .recall, .context]
        }
    }

    /// Si ricava da quante volte il kanji è già comparso, e non si salva: un secondo
    /// contatore accanto a `presentationCount` sarebbe un secondo contatore da tenere
    /// allineato, cioè un modo per finire a mostrare "ricorda?" a chi quel kanji non
    /// l'ha mai visto.
    /// Le prime tre volte sono uguali per tutti: insegna, richiama, mostra dentro una
    /// parola. È la grammatica dell'app, e cambiarla a seconda dei segnali vorrebbe
    /// dire partire già storti su un kanji di cui non sappiamo ancora niente.
    public static func forSightings(
        _ count: Int,
        support: SupportLevel = .low,
        hasWord: Bool
    ) -> ExposureContent {
        let giro = rhythm(for: support)
        let chosen: ExposureContent =
            switch count {
            case ..<1: .introduce
            case 1: .recall
            case 2: .context
            default: giro[(count - 3) % giro.count]
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

/// *Quale* materiale mostrare, accanto a *come* (`ExposureContent`).
///
/// Due decisioni diverse: la forma dice che è il momento della parola, il riferimento
/// dice quale delle parole di quel kanji. Tenute insieme in un campo solo, la prima
/// volta che servirà una frase d'esempio andrebbero separate a forza.
public enum ExposureReference: Equatable, Hashable, Sendable, Codable {
    /// Niente di specifico: il kanji da solo, o la parola più comune.
    case none
    /// Una delle parole del kanji, per posizione.
    case word(Int)

    /// La parola che tocca: girano una per volta che il kanji compare dentro una
    /// parola. Nessun caso — altrimenti notifica, quadrante e app potrebbero
    /// pescarne tre diverse per lo stesso momento.
    public static func next(for content: ExposureContent, words: [Kanji.Word], contextsSoFar: Int) -> Self {
        guard content == .context, !words.isEmpty else { return .none }
        return .word(contextsSoFar % words.count)
    }
}
