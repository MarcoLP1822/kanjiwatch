import Foundation

/// La finestra in cui l'app può farsi viva.
///
/// Non è un `ClosedRange<Int>` come nella prima stesura del documento: una
/// finestra che attraversa la mezzanotte (22→6) non si può scrivere come
/// `22...6`, va in crash alla costruzione. Qui il caso è esplicito.
public struct ActiveHours: Equatable, Sendable, Codable {
    /// Ora di inizio, 0-23. Le notifiche partono a `startHour:00`.
    public let startHour: Int
    /// Ora di fine, esclusa: con 22 l'ultima notifica può arrivare alle 21:59.
    public let endHour: Int

    public init(startHour: Int, endHour: Int) {
        self.startHour = min(max(startHour, 0), 23)
        self.endHour = min(max(endHour, 0), 23)
    }

    /// Vero per 22→6, e anche quando inizio e fine coincidono: in quel caso la
    /// finestra è l'intera giornata, che è l'unica lettura sensata di "dalle 8
    /// alle 8".
    public var crossesMidnight: Bool { endHour <= startHour }

    public func contains(hour: Int) -> Bool {
        crossesMidnight
            ? (hour >= startHour || hour < endHour)
            : (hour >= startHour && hour < endHour)
    }

    /// Quante ore dura la finestra. Serve a capire quante notifiche ci stanno.
    public var durationInHours: Int {
        crossesMidnight ? (24 - startHour + endHour) : (endHour - startHour)
    }
}

/// Le uniche cose che l'utente può cambiare.
public struct ReminderSettings: Equatable, Sendable, Codable {
    public var intervalMinutes: Int
    public var activeHours: ActiveHours
    /// Modalità discreta: la notifica non accende lo schermo e si accumula nella
    /// lista, da guardare quando ti va. Per un ripasso passivo è una scelta seria.
    public var isPassive: Bool
    /// I gradi scolastici da ripassare, cioè i mazzi attivi.
    public var grades: Set<Int>
    /// Quanti kanji nuovi al giorno, tra notifiche arrivate e NEXT. L'intervallo dà
    /// il ritmo, questo il tetto: raggiunto il numero, la giornata è finita.
    public var dailyLimit: Int
    /// Il tema scelto. Sta qui e non in un archivio a parte perché segue le stesse regole
    /// di accesso delle altre scelte Premium, e si salva allo stesso modo.
    public var theme: AppTheme

    public init(
        intervalMinutes: Int,
        activeHours: ActiveHours,
        isPassive: Bool,
        grades: Set<Int> = KanjiLevel.freeGrades,
        dailyLimit: Int = ReminderSettings.defaultDailyLimit,
        theme: AppTheme = .aiZome
    ) {
        self.intervalMinutes = intervalMinutes
        self.activeHours = activeHours
        self.isPassive = isPassive
        self.grades = grades
        self.dailyLimit = dailyLimit
        self.theme = theme
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        intervalMinutes = try container.decode(Int.self, forKey: .intervalMinutes)
        activeHours = try container.decode(ActiveHours.self, forKey: .activeHours)
        isPassive = try container.decode(Bool.self, forKey: .isPassive)
        // Impostazioni salvate prima dei campi nuovi: senza i default la decodifica
        // fallirebbe, e con lei si perderebbero intervallo e fascia oraria.
        grades = try container.decodeIfPresent(Set<Int>.self, forKey: .grades) ?? KanjiLevel.freeGrades
        dailyLimit = try container.decodeIfPresent(Int.self, forKey: .dailyLimit) ?? Self.defaultDailyLimit
        // Un tema sconosciuto, per esempio tolto in un aggiornamento, torna a quello di base.
        theme = (try? container.decodeIfPresent(AppTheme.self, forKey: .theme)) ?? .aiZome
    }

    public static let defaultDailyLimit = 10

    /// Default: un kanji all'ora dalle 8 alle 22, al massimo dieci al giorno, mazzo
    /// gratuito. Senza fascia di silenzio l'app ti sveglia alle 3 di notte e la
    /// disinstalli il giorno dopo.
    public static let `default` = ReminderSettings(
        intervalMinutes: 60,
        activeHours: ActiveHours(startHour: 8, endHour: 22),
        isPassive: false,
        grades: KanjiLevel.freeGrades,
        dailyLimit: defaultDailyLimit
    )

    /// Gli intervalli proposti nelle impostazioni: pochi e tondi, si scelgono
    /// con la corona in due giri.
    public static let offeredIntervals = [15, 30, 45, 60, 90, 120, 180, 240]

    public static let offeredDailyLimits = [3, 5, 10, 15, 20, 30]
}
