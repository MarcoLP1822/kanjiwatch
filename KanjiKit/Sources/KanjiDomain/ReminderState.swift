import Foundation

/// Quello che l'app deve ricordarsi tra un avvio e l'altro.
public struct ReminderState: Equatable, Sendable, Codable {
    /// Le notifiche ancora in coda: servono a sapere quali kanji erano già stati
    /// estratti ma non ancora mostrati, quando si rischedula.
    public var scheduled: [ScheduledReminder]
    /// Il kanji in gioco e se l'hai chiuso con DONE.
    public var session: StudySession
    /// Quanti kanji nuovi ha già avuto la giornata, tra notifiche arrivate e NEXT.
    public var today: DailyCount
    /// Da quando riparte l'intervallo: l'ultimo NEXT. Vale solo per la sua giornata.
    public var anchor: Date?

    public init(
        scheduled: [ScheduledReminder] = [],
        session: StudySession = .none,
        today: DailyCount = .none,
        anchor: Date? = nil
    ) {
        self.scheduled = scheduled
        self.session = session
        self.today = today
        self.anchor = anchor
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        scheduled = try container.decode([ScheduledReminder].self, forKey: .scheduled)
        // Stato salvato prima che esistesse il loop: senza i default si perderebbe
        // anche il punto del giro nel mazzo.
        session = try container.decodeIfPresent(StudySession.self, forKey: .session) ?? .none
        today = try container.decodeIfPresent(DailyCount.self, forKey: .today) ?? .none
        anchor = try container.decodeIfPresent(Date.self, forKey: .anchor)
    }

    /// Primo avvio: nessuna coda e nessun kanji in gioco. Il primo se lo sceglie
    /// l'Ambient Engine alla prima lettura dello stato.
    public static let empty = ReminderState()
}

/// Il kanji in gioco.
public struct StudySession: Equatable, Sendable, Codable {
    public var codepoint: String?
    /// Chiuso con DONE: si aspetta il prossimo.
    public var isDone: Bool
    /// Quando è entrato in gioco. Una notifica arrivata dopo ne prende il posto.
    public var since: Date?
    /// In che forma è arrivato: la stessa della notifica che l'ha portato. Il
    /// quadrante la rilegge da qui, così i due non si contraddicono.
    public var content: ExposureContent

    public init(codepoint: String?, isDone: Bool, since: Date?, content: ExposureContent = .introduce) {
        self.codepoint = codepoint
        self.isDone = isDone
        self.since = since
        self.content = content
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        codepoint = try container.decodeIfPresent(String.self, forKey: .codepoint)
        isDone = try container.decode(Bool.self, forKey: .isDone)
        since = try container.decodeIfPresent(Date.self, forKey: .since)
        // Sessioni salvate prima della micro-sequenza: erano tutte "kanji e significato".
        content = (try? container.decodeIfPresent(ExposureContent.self, forKey: .content)) ?? .introduce
    }

    public static let none = StudySession(codepoint: nil, isDone: false, since: nil)
}

/// I kanji di una giornata di calendario.
public struct DailyCount: Equatable, Sendable, Codable {
    public var day: Date
    public var count: Int

    public init(day: Date, count: Int) {
        self.day = day
        self.count = count
    }

    public static let none = DailyCount(day: .distantPast, count: 0)

    public func count(on date: Date, calendar: Calendar) -> Int {
        calendar.isDate(day, inSameDayAs: date) ? count : 0
    }

    public mutating func add(_ amount: Int, on date: Date, calendar: Calendar) {
        if calendar.isDate(day, inSameDayAs: date) {
            count += amount
        } else {
            day = calendar.startOfDay(for: date)
            count = amount
        }
    }
}
