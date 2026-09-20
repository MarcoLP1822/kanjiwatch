import Foundation
import KanjiDomain

/// Il contratto tra chi schedula la notifica e chi la riceve: categoria, codepoint e
/// forma dell'esposizione stanno scritti qui una volta sola, perché a usarli sono tre
/// punti diversi — lo scheduler, il delegate e la scena della long look.
public enum ReminderPayload {
    /// Deve coincidere con la categoria della `WKNotificationScene`, altrimenti
    /// la notifica personalizzata non viene mai mostrata.
    public static let categoryIdentifier = "KANJI_REVIEW"

    private static let codepointKey = "cp"
    private static let contentKey = "ec"

    public static func userInfo(for destination: ReminderDestination) -> [String: String] {
        [codepointKey: destination.codepoint, contentKey: destination.content.rawValue]
    }

    public static func destination(from userInfo: [AnyHashable: Any]) -> ReminderDestination? {
        guard let codepoint = userInfo[codepointKey] as? String else { return nil }
        // Notifiche già in coda quando l'app si aggiorna: senza forma, sono "kanji e
        // significato", che è come si comportavano prima.
        let content = (userInfo[contentKey] as? String).flatMap(ExposureContent.init(rawValue:)) ?? .introduce
        return ReminderDestination(codepoint: codepoint, content: content)
    }
}
