import Foundation

private let CACHE_KEY_TEAMS  = "wede_cache_teams"
private let CACHE_KEY_META   = "wede_cache_meta"
private let CACHE_TTL_MS: TimeInterval = 5 * 60

public class WedeCache {
    private let storage: WedeStorage
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(storage: WedeStorage) { self.storage = storage }

    public func setTeams(_ teams: [TeamInput]) async {
        if let data = try? encoder.encode(teams),
           let str = String(data: data, encoding: .utf8) {
            await storage.setItem(CACHE_KEY_TEAMS, value: str)
            await storage.setItem(CACHE_KEY_META, value: String(Date().timeIntervalSince1970))
        }
    }

    public func getTeams() async -> [TeamInput]? {
        guard let raw = await storage.getItem(CACHE_KEY_TEAMS),
              let data = raw.data(using: .utf8) else { return nil }
        if let metaStr = await storage.getItem(CACHE_KEY_META),
           let metaTs = Double(metaStr) {
            let age = Date().timeIntervalSince1970 - metaTs
            if age > CACHE_TTL_MS { return nil }
        }
        return try? decoder.decode([TeamInput].self, from: data)
    }

    public func clear() async {
        await storage.removeItem(CACHE_KEY_TEAMS)
        await storage.removeItem(CACHE_KEY_META)
    }
}
