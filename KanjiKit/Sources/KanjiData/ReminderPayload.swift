import Foundation

/// Il contratto tra chi schedula la notifica e chi la riceve: categoria e
/// codepoint stanno scritti qui una volta sola, perché a usarli sono tre punti
/// diversi — lo scheduler, il delegate e la scena della long look.
public enum ReminderPayload {
    /// Deve coincidere con la categoria della `WKNotificationScene`, altrimenti
    /// la notifica personalizzata non viene mai mostrata.
    public static let categoryIdentifier = "KANJI_REVIEW"

    private static let codepointKey = "cp"

    public static func userInfo(codepoint: String) -> [String: String] {
        [codepointKey: codepoint]
    }

    public static func codepoint(from userInfo: [AnyHashable: Any]) -> String? {
        userInfo[codepointKey] as? String
    }
}
