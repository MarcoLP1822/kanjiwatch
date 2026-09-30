import Foundation

/// Lo stato del permesso, visto dal dominio. Non è `UNAuthorizationStatus`: se lo
/// fosse, il dominio si porterebbe dietro UserNotifications e non si potrebbe più
/// provare senza simulatore.
public enum NotificationAuthorization: Equatable, Sendable {
    case notDetermined
    case denied
    case authorized
}

/// Chiede e legge il permesso di notificare.
public protocol NotificationAuthorizing {
    func authorizationStatus() async -> NotificationAuthorization
    /// Ritorna `true` se l'utente ha concesso il permesso.
    @discardableResult
    func requestAuthorization() async -> Bool
}

/// Una notifica pronta da consegnare al sistema: il carattere serve perché è lui
/// il titolo — è quello che leggi alzando il polso per mezzo secondo — e il
/// codepoint per riaprire l'app sul kanji giusto.
///
/// Porta anche significato e parola d'esempio: l'adattatore deve poter scrivere
/// tutte e tre le forme senza andarsi a ricaricare il mazzo.
public struct PlannedNotification: Equatable, Sendable {
    public let fireDate: Date
    public let codepoint: String
    public let character: String
    public let meaning: String
    /// La parola già risolta: quella che il piano ha scelto per questo momento.
    public let word: Kanji.Word?
    /// In che forma mostrarlo. Decisa dal piano, non ricalcolata da chi consegna.
    public let content: ExposureContent
    public let reference: ExposureReference

    public init(
        fireDate: Date,
        codepoint: String,
        character: String,
        meaning: String = "",
        word: Kanji.Word? = nil,
        content: ExposureContent = .introduce,
        reference: ExposureReference = .none
    ) {
        self.fireDate = fireDate
        self.codepoint = codepoint
        self.character = character
        self.meaning = meaning
        self.word = word
        self.content = content.resolved(hasWord: word != nil)
        self.reference = reference
    }

    public init(fireDate: Date, kanji: Kanji, content: ExposureContent, reference: ExposureReference = .none) {
        self.init(
            fireDate: fireDate,
            codepoint: kanji.codepoint,
            character: kanji.character,
            meaning: kanji.shortMeaning,
            word: kanji.word(for: reference),
            content: content,
            reference: reference
        )
    }

    public var destination: ReminderDestination {
        ReminderDestination(codepoint: codepoint, content: content, reference: reference)
    }
}

/// Mette le notifiche in coda.
///
/// La coda si sostituisce sempre per intero, mai a pezzi: il piano è ricalcolato
/// da zero a ogni occasione, ed è l'unico modo per essere sicuri che le 64
/// notifiche in attesa siano esattamente quelle che ci si aspetta.
public protocol ReminderScheduling {
    func replacePending(with notifications: [PlannedNotification], isPassive: Bool) async
    func cancelAll() async
    /// Le notifiche arrivate e ancora nel Centro notifiche: quelle che non hai aperto.
    func delivered() async -> [DeliveredReminder]
    func removeDelivered(_ identifiers: [String]) async
}

extension ReminderScheduling {
    public func delivered() async -> [DeliveredReminder] { [] }
    public func removeDelivered(_ identifiers: [String]) async {}
}

/// Una notifica arrivata che è ancora lì, nel Centro notifiche.
public struct DeliveredReminder: Equatable, Sendable {
    public let identifier: String
    public let date: Date
    public let destination: ReminderDestination

    public init(identifier: String, date: Date, destination: ReminderDestination) {
        self.identifier = identifier
        self.date = date
        self.destination = destination
    }
}

/// I kanji di oggi arrivati senza che tu li aprissi. Si decide qui, e non nella view,
/// perché la regola è di dominio: conta solo oggi, conta un kanji una volta, e il kanji
/// che l'app ti sta mostrando l'hai visto.
public enum MissedToday {
    public static func destinations(
        from delivered: [DeliveredReminder],
        showing codepoint: String?,
        now: Date,
        calendar: Calendar = .current
    ) -> [ReminderDestination] {
        var seen = Set<String>()
        return delivered
            .filter { calendar.isDate($0.date, inSameDayAs: now) && $0.destination.codepoint != codepoint }
            .sorted { $0.date < $1.date }
            .compactMap { seen.insert($0.destination.codepoint).inserted ? $0.destination : nil }
    }
}

/// Un valore che sopravvive al riavvio dell'app. Due implementazioni: UserDefaults
/// nell'app, in memoria nei test.
public protocol ValueStore<Value> {
    associatedtype Value
    func load() -> Value
    func save(_ value: Value)
}
