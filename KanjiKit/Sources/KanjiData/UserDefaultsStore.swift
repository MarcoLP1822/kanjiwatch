import Foundation
import KanjiDomain

/// Un valore Codable dentro UserDefaults.
///
/// Niente database: le cose da ricordare sono tre, e app e notifiche girano nello
/// stesso contenitore, quindi non serve nemmeno un App Group.
public struct UserDefaultsStore<Value: Codable>: ValueStore {
    private let defaults: UserDefaults
    private let key: String
    private let fallback: Value

    public init(key: String, default fallback: Value, defaults: UserDefaults = .standard) {
        self.key = key
        self.fallback = fallback
        self.defaults = defaults
    }

    public func load() -> Value {
        guard
            let data = defaults.data(forKey: key),
            let decoded = try? JSONDecoder().decode(Value.self, from: data)
        else {
            // Dati vecchi o illeggibili: si riparte dal default invece di bloccarsi.
            return fallback
        }
        return decoded
    }

    public func save(_ value: Value) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}

extension UserDefaultsStore where Value == ReminderSettings {
    public static func settings(defaults: UserDefaults = .standard) -> Self {
        Self(key: "reminder.settings", default: .default, defaults: defaults)
    }
}

extension UserDefaultsStore where Value == ReminderState {
    public static func reminderState(defaults: UserDefaults = .standard) -> Self {
        Self(key: "reminder.state", default: .empty, defaults: defaults)
    }
}
