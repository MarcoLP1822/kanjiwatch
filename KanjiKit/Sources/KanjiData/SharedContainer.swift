import Foundation
import KanjiDomain

/// Il contenitore condiviso tra l'app e la complication.
///
/// La complication gira in un processo separato e non vede lo `UserDefaults` dell'app:
/// per questo le serve un App Group. L'identificativo deve coincidere con quello
/// dichiarato negli entitlement di entrambi i target.
public enum SharedContainer {
    public static let appGroup = "group.com.marcolp.KanjiWatch"

    /// Se l'entitlement manca si ricade sullo standard: l'app continua a funzionare
    /// e la complication resta soltanto vuota.
    public static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }
}

extension UserDefaultsStore where Value == [GlanceEntry] {
    /// La timeline pronta da disegnare: l'app la scrive dopo ogni rischedulazione,
    /// la complication la legge e basta.
    public static func complicationTimeline(defaults: UserDefaults = SharedContainer.defaults) -> Self {
        Self(key: "complication.timeline", default: [], defaults: defaults)
    }
}
