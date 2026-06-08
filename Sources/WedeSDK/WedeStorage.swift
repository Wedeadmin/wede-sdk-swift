import Foundation

/// Abstract storage interface — implement with UserDefaults, Keychain, or Core Data.
/// Follows the same pattern as SDK JS/RN/Android WedeStorage.
public protocol WedeStorage {
    func getItem(_ key: String) async -> String?
    func setItem(_ key: String, value: String) async
    func removeItem(_ key: String) async
}

/// Simple UserDefaults-backed storage — use for non-sensitive data.
public class UserDefaultsStorage: WedeStorage {
    private let defaults: UserDefaults

    public init(suiteName: String? = nil) {
        self.defaults = UserDefaults(suiteName: suiteName) ?? .standard
    }

    public func getItem(_ key: String) async -> String? {
        return defaults.string(forKey: key)
    }

    public func setItem(_ key: String, value: String) async {
        defaults.set(value, forKey: key)
    }

    public func removeItem(_ key: String) async {
        defaults.removeObject(forKey: key)
    }
}
