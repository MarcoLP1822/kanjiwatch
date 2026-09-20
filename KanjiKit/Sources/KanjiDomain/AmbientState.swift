import Foundation

/// Quello che il kanji ha già fatto sul tuo polso.
///
/// Non c'è nessun "lo so / non lo so": chiederlo sarebbe lavoro, e questa app non
/// chiede niente. Tutto quello che sa lo ricava da segnali che l'utente lascia
/// gratis — la notifica arrivata, l'app aperta su quel kanji, le letture viste.
public struct KanjiExposure: Equatable, Sendable, Codable {
    public var firstSeenAt: Date
    public var lastPresentedAt: Date
    /// Quante volte è comparso, aperto o no.
    public var presentationCount: Int
    /// Quante volte l'app è stata aperta su di lui, da una notifica o dal quadrante.
    public var openedCount: Int
    /// Quante volte sei arrivato fino a letture e parola: il segnale più forte che
    /// abbiamo senza domandare niente.
    public var readingsViewedCount: Int
    public var lastEngagedAt: Date?
    /// Da quando ha di nuovo senso riproporlo. Non è una scadenza da rispettare: è
    /// la chiave con cui il motore decide chi è più in ritardo.
    public var nextDueAt: Date
    /// Quanto quel kanji sembra chiedere un appiglio, da 0 a 1. Cresce solo quando,
    /// vedendolo da solo, sei andato a cercare il resto; e cala da sé col tempo,
    /// perché una fatica di due mesi fa non deve perseguitare un kanji per sempre.
    public var supportScore: Double
    /// Quando il punteggio è stato toccato l'ultima volta: senza, non si saprebbe da
    /// quando farlo decadere.
    public var supportUpdatedAt: Date?

    public init(
        firstSeenAt: Date,
        lastPresentedAt: Date,
        presentationCount: Int = 0,
        openedCount: Int = 0,
        readingsViewedCount: Int = 0,
        lastEngagedAt: Date? = nil,
        nextDueAt: Date,
        supportScore: Double = 0,
        supportUpdatedAt: Date? = nil
    ) {
        self.firstSeenAt = firstSeenAt
        self.lastPresentedAt = lastPresentedAt
        self.presentationCount = presentationCount
        self.openedCount = openedCount
        self.readingsViewedCount = readingsViewedCount
        self.lastEngagedAt = lastEngagedAt
        self.nextDueAt = nextDueAt
        self.supportScore = supportScore
        self.supportUpdatedAt = supportUpdatedAt
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        firstSeenAt = try container.decode(Date.self, forKey: .firstSeenAt)
        lastPresentedAt = try container.decode(Date.self, forKey: .lastPresentedAt)
        presentationCount = try container.decode(Int.self, forKey: .presentationCount)
        openedCount = try container.decode(Int.self, forKey: .openedCount)
        readingsViewedCount = try container.decode(Int.self, forKey: .readingsViewedCount)
        lastEngagedAt = try container.decodeIfPresent(Date.self, forKey: .lastEngagedAt)
        nextDueAt = try container.decode(Date.self, forKey: .nextDueAt)
        // Storici salvati prima del ritmo personale: nessun segnale, e si riparte
        // da lì invece di buttare via mesi di esposizioni.
        supportScore = try container.decodeIfPresent(Double.self, forKey: .supportScore) ?? 0
        supportUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .supportUpdatedAt)
    }
}

/// Quanto un kanji è già passato davanti. **Non** quanto lo si conosce: di questo
/// non abbiamo nessuna prova, e chiamarlo `known` sarebbe una bugia comoda.
public enum FamiliarityStage: Equatable, Hashable, Sendable, CaseIterable {
    /// Appena entrato, o visto pochissime volte.
    case fresh
    /// In mezzo: lo sta incontrando.
    case reinforcing
    /// Ci è passato davanti parecchie volte, o ci è entrato dentro più di una volta.
    case familiar
}

/// I tre segnali che raccogliamo. Nessuno costa un gesto in più all'utente.
public enum ExposureEvent: Equatable, Sendable {
    /// Il kanji è comparso: notifica arrivata, primo kanji dell'app, o NEXT.
    case presented
    /// L'app si è aperta su di lui.
    case opened
    /// Sei arrivato alle letture.
    case readingsViewed
}

/// Lo storico delle esposizioni: l'unica memoria che ha l'Ambient Engine.
///
/// Non sta dentro `ReminderState` perché le due cose rispondono a domande diverse —
/// lì cosa è successo alle notifiche, qui cosa ha incontrato l'utente — e perché
/// cresce: un record per kanji incontrato, non per kanji del mazzo.
public struct AmbientState: Equatable, Sendable, Codable {
    public var records: [String: KanjiExposure]

    public init(records: [String: KanjiExposure] = [:]) {
        self.records = records
    }

    public static let empty = AmbientState()

    /// Lo stadio calcolato al momento, mai salvato: salvarlo vorrebbe dire poterlo
    /// avere disallineato dai conteggi da cui dipende.
    public func stage(of codepoint: String, at date: Date) -> FamiliarityStage? {
        records[codepoint]?.stage(at: date)
    }

    /// Quanto supporto sembra chiedere quel kanji, adesso.
    public func support(of codepoint: String, at date: Date) -> SupportLevel {
        records[codepoint]?.supportLevel(at: date) ?? .low
    }

    /// `content` dice in che forma il kanji era davanti agli occhi: toccare un kanji
    /// mostrato da solo vuol dire una cosa, toccarlo mentre c'è già il significato
    /// scritto sotto non vuol dire niente.
    public mutating func record(
        _ event: ExposureEvent,
        codepoint: String,
        content: ExposureContent = .introduce,
        at date: Date
    ) {
        var exposure =
            records[codepoint]
            ?? KanjiExposure(firstSeenAt: date, lastPresentedAt: date, nextDueAt: date)
        let before = exposure.stage(at: date)

        switch event {
        case .presented:
            exposure.presentationCount += 1
            exposure.lastPresentedAt = date
        case .opened:
            exposure.openedCount += 1
            exposure.lastEngagedAt = date
        case .readingsViewed:
            exposure.readingsViewedCount += 1
            exposure.lastEngagedAt = date
        }
        // Un kanji aperto è stato per forza mostrato, anche se la notifica che l'ha
        // portato è arrivata prima che esistesse questo storico.
        exposure.presentationCount = max(exposure.presentationCount, 1)

        // Solo il richiamo dice qualcosa: se il kanji era lì da solo e sei andato a
        // cercare il resto, un appiglio in più può servire. Cercarlo quando il
        // significato c'era già scritto è comportamento normale, non una richiesta.
        if content == .recall, let weight = KanjiExposure.supportWeight(for: event) {
            exposure.supportScore = min(1, exposure.support(at: date) + weight)
            exposure.supportUpdatedAt = date
        }

        switch event {
        case .presented:
            // La prima volta torna presto: un kanji visto una volta sola e poi sparito
            // per un giorno non ha lasciato niente.
            let spacing =
                exposure.presentationCount <= 1
                ? KanjiExposure.firstSpacing
                : KanjiExposure.spacing(for: exposure.stage(at: date))
            exposure.nextDueAt = date + spacing
        case .opened:
            break
        case .readingsViewed:
            // Chi è arrivato alle letture ha fatto il lavoro: può stare via di più.
            exposure.nextDueAt = max(exposure.nextDueAt, date + KanjiExposure.engagedSpacing(for: before))
        }

        records[codepoint] = exposure
    }
}

extension KanjiExposure {
    public func stage(at date: Date) -> FamiliarityStage {
        let age = date.timeIntervalSince(firstSeenAt)
        // Due strade per la familiarità. La seconda è quella che conta davvero per
        // questa app: se non tocchi mai l'orologio, vedere un kanji ottanta volte
        // deve valere comunque qualcosa.
        if presentationCount >= 4, readingsViewedCount >= 2, age >= 2 * .day { return .familiar }
        if presentationCount >= 8, age >= 7 * .day { return .familiar }
        if presentationCount < 3, readingsViewedCount == 0 { return .fresh }
        return .reinforcing
    }

    /// Il punteggio di adesso: quello salvato, dimezzato ogni due settimane. Così
    /// un kanji che ti aveva dato filo da torcere a marzo, se a maggio lo guardi e
    /// basta, torna a essere un kanji come gli altri.
    public func support(at date: Date) -> Double {
        guard let supportUpdatedAt, supportScore > 0 else { return 0 }
        let elapsed = max(date.timeIntervalSince(supportUpdatedAt), 0)
        return supportScore * pow(0.5, elapsed / Self.supportHalfLife)
    }

    public func supportLevel(at date: Date) -> SupportLevel {
        switch support(at: date) {
        case ..<0.25: .low
        case ..<0.60: .medium
        default: .high
        }
    }

    static let supportHalfLife: TimeInterval = 14 * .day

    /// Aprire l'app su un kanji mostrato da solo pesa più che arrivare fino alle
    /// letture: il primo tocco è già la richiesta, il resto è la conferma.
    static func supportWeight(for event: ExposureEvent) -> Double? {
        switch event {
        case .opened: 0.30
        case .readingsViewed: 0.25
        case .presented: nil
        }
    }

    /// Il ritmo. Numeri scelti a occhio e da ritoccare con l'uso: non stiamo
    /// costruendo un SRS, stiamo distribuendo incontri nella giornata.
    static let firstSpacing: TimeInterval = 6 * .hour

    static func spacing(for stage: FamiliarityStage) -> TimeInterval {
        switch stage {
        case .fresh: 18 * .hour
        case .reinforcing: 3 * .day
        case .familiar: 10 * .day
        }
    }

    /// Dopo le letture la distanza minima cresce, a partire da dov'era il kanji
    /// prima del gesto.
    static func engagedSpacing(for stage: FamiliarityStage) -> TimeInterval {
        switch stage {
        case .fresh: 1 * .day
        case .reinforcing: 3 * .day
        case .familiar: 10 * .day
        }
    }
}

extension TimeInterval {
    static let hour: TimeInterval = 3600
    static let day: TimeInterval = 24 * .hour
}
