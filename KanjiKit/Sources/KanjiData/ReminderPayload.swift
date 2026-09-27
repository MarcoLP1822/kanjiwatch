import Foundation
import KanjiDomain
import UserNotifications

/// Il contratto tra chi schedula la notifica e chi la riceve: categoria, codepoint e
/// forma dell'esposizione stanno scritti qui una volta sola, perché a usarli sono tre
/// punti diversi — lo scheduler, il delegate e la scena della long look.
public enum ReminderPayload {
    /// Deve coincidere con la categoria della `WKNotificationScene`, altrimenti
    /// la notifica personalizzata non viene mai mostrata.
    public static let categoryIdentifier = "KANJI_REVIEW"

    /// Il bottone del kanji da solo. Non apre l'app: la risposta arriva al delegate in
    /// background, e col ritmo personale quel kanji torna prima.
    public static let forgotActionIdentifier = "FORGOT"

    public static var forgotAction: UNNotificationAction {
        UNNotificationAction(
            identifier: forgotActionIdentifier,
            title: String(localized: "I didn't remember", bundle: .module)
        )
    }

    private static let codepointKey = "cp"
    private static let contentKey = "ec"
    private static let wordKey = "wi"

    public static func userInfo(for destination: ReminderDestination) -> [String: String] {
        var info = [codepointKey: destination.codepoint, contentKey: destination.content.rawValue]
        if case .word(let index) = destination.reference {
            info[wordKey] = String(index)
        }
        return info
    }

    public static func destination(from userInfo: [AnyHashable: Any]) -> ReminderDestination? {
        guard let codepoint = userInfo[codepointKey] as? String else { return nil }
        // Notifiche già in coda quando l'app si aggiorna: senza forma, sono "kanji e
        // significato", e senza parola scelta si usa la più comune — com'era prima.
        let content = (userInfo[contentKey] as? String).flatMap(ExposureContent.init(rawValue:)) ?? .introduce
        let reference = (userInfo[wordKey] as? String).flatMap(Int.init).map(ExposureReference.word) ?? .none
        return ReminderDestination(codepoint: codepoint, content: content, reference: reference)
    }
}
