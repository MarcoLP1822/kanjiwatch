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
public struct PlannedNotification: Equatable, Sendable {
    public let fireDate: Date
    public let codepoint: String
    public let character: String

    public init(fireDate: Date, codepoint: String, character: String) {
        self.fireDate = fireDate
        self.codepoint = codepoint
        self.character = character
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
}

/// Un valore che sopravvive al riavvio dell'app. Due implementazioni: UserDefaults
/// nell'app, in memoria nei test.
public protocol ValueStore<Value> {
    associatedtype Value
    func load() -> Value
    func save(_ value: Value)
}
