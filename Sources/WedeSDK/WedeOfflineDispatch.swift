import Foundation

public struct OfflineDispatchRequest: Codable {
    public let id: String
    public let actionId: String
    public let event: EventInput
    public let teamId: String
    public let teamName: String
    public let score: Double
    public let channel: String
    public let queuedAt: String
    public let synced: Bool
    public let sequenceNumber: Int64
}

public struct DispatchOfflineResult {
    public let success: Bool
    public let team: ScoredTeam?
    public let queued: Bool
    public let queueId: String?
    public let reason: String?
}

private let QUEUE_KEY = "wede_offline_dispatch_queue"
private let DEVICE_ID_KEY = "wede_device_id"

/**
 * Wede Offline Dispatch — Swift SDK
 * Guaranteed delivery of operational dispatches without connectivity.
 * Patent INPI 120488 — Claim 5 implementation.
 */
public class WedeOfflineDispatch {
    private let storage: WedeStorage
    private let cache: WedeCache
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(storage: WedeStorage) {
        self.storage = storage
        self.cache = WedeCache(storage: storage)
    }

    public func scoreLocally(event: EventInput) async -> [ScoredTeam] {
        guard let teams = await cache.getTeams() else { return [] }
        return ScoreEngine.scoreTeams(teams, evt: event)
    }

    public func dispatch(actionId: String, event: EventInput) async -> DispatchOfflineResult {
        let scored = await scoreLocally(event: event)
        let best = scored.first { $0.status == "available" } ?? scored.first

        guard let best = best else {
            return DispatchOfflineResult(success: false, team: nil, queued: false,
                                         queueId: nil, reason: "no_teams_cached")
        }

        let seq = await getNextSequence()
        let id = UUID().uuidString
        let entry = OfflineDispatchRequest(
            id: id, actionId: actionId, event: event,
            teamId: best.teamId, teamName: best.teamName,
            score: best.score, channel: best.channel,
            queuedAt: ISO8601DateFormatter().string(from: Date()),
            synced: false, sequenceNumber: seq
        )

        await enqueue(entry)
        return DispatchOfflineResult(success: true, team: best, queued: true, queueId: id, reason: nil)
    }

    public func getPendingQueue() async -> [OfflineDispatchRequest] {
        return await getAllQueue().filter { !$0.synced }
    }

    public func markSynced(_ id: String) async {
        var all = await getAllQueue()
        all = all.map { $0.id == id ? OfflineDispatchRequest(
            id: $0.id, actionId: $0.actionId, event: $0.event,
            teamId: $0.teamId, teamName: $0.teamName, score: $0.score,
            channel: $0.channel, queuedAt: $0.queuedAt, synced: true,
            sequenceNumber: $0.sequenceNumber) : $0 }
        if let data = try? encoder.encode(all),
           let str = String(data: data, encoding: .utf8) {
            await storage.setItem(QUEUE_KEY, value: str)
        }
    }

    public func clearSynced() async {
        let pending = await getAllQueue().filter { !$0.synced }
        if let data = try? encoder.encode(pending),
           let str = String(data: data, encoding: .utf8) {
            await storage.setItem(QUEUE_KEY, value: str)
        }
    }

    public func queueSize() async -> Int { await getPendingQueue().count }

    private func getAllQueue() async -> [OfflineDispatchRequest] {
        guard let raw = await storage.getItem(QUEUE_KEY),
              let data = raw.data(using: .utf8),
              let queue = try? decoder.decode([OfflineDispatchRequest].self, from: data)
        else { return [] }
        return queue
    }

    private func enqueue(_ entry: OfflineDispatchRequest) async {
        var all = await getAllQueue()
        all.append(entry)
        if let data = try? encoder.encode(all),
           let str = String(data: data, encoding: .utf8) {
            await storage.setItem(QUEUE_KEY, value: str)
        }
    }

    private func getNextSequence() async -> Int64 {
        let all = await getAllQueue()
        return (all.map { $0.sequenceNumber }.max() ?? 0) + 1
    }
}

public class WedeDeviceId {
    private let storage: WedeStorage

    public init(storage: WedeStorage) { self.storage = storage }

    public func getOrCreate() async -> String {
        if let existing = await storage.getItem(DEVICE_ID_KEY), !existing.isEmpty {
            return existing
        }
        let newId = UUID().uuidString
        await storage.setItem(DEVICE_ID_KEY, value: newId)
        return newId
    }

    public func get() async -> String? { await storage.getItem(DEVICE_ID_KEY) }
}
