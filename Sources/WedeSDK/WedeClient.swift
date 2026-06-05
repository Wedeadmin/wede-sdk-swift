import Foundation

public actor WedeClient {
    private let apiKey: String
    private let baseURL: URL
    private let timeout: TimeInterval
    private let retries: Int
    private let session: URLSession

    public init(
        apiKey: String,
        baseURL: String = "https://api.wede.pt",
        timeout: TimeInterval = 10,
        retries: Int = 3
    ) {
        self.apiKey = apiKey
        self.baseURL = URL(string: baseURL)!
        self.timeout = timeout
        self.retries = retries
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        self.session = URLSession(configuration: config)
    }

    private func request<T: Decodable>(
        method: String,
        path: String,
        body: Encodable? = nil,
        attempt: Int = 1
    ) async throws -> T {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = method
        req.setValue(apiKey, forHTTPHeaderField: "x-wede-api-key")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body = body {
            req.httpBody = try JSONEncoder().encode(body)
        }
        do {
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse else {
                throw WedeError.networkError("Invalid response")
            }
            if http.statusCode == 401 { throw WedeError.authError("Invalid or missing API key") }
            if http.statusCode >= 400 {
                let err = try? JSONDecoder().decode([String: String].self, from: data)
                throw WedeError.apiError(err?["message"] ?? "Request failed", http.statusCode)
            }
            return try JSONDecoder().decode(T.self, from: data)
        } catch let error as WedeError {
            throw error
        } catch {
            if attempt < retries {
                try await Task.sleep(nanoseconds: UInt64(300_000_000 * attempt))
                return try await request(method: method, path: path, body: body, attempt: attempt + 1)
            }
            throw WedeError.networkError(error.localizedDescription)
        }
    }

    // Events
    public func sendEvent(_ event: WedeEvent) async throws -> [String: String] {
        return try await request(method: "POST", path: "/v1/events", body: event)
    }

    public func listEvents(zoneId: String? = nil, vertical: String? = nil) async throws -> WedeResponse<[WedeEvent]> {
        var path = "/v1/events"
        var params: [String] = []
        if let z = zoneId { params.append("zone_id=\(z)") }
        if let v = vertical { params.append("vertical=\(v)") }
        if !params.isEmpty { path += "?" + params.joined(separator: "&") }
        return try await request(method: "GET", path: path)
    }

    // Zones
    public func listZones() async throws -> WedeResponse<[WedeZone]> {
        return try await request(method: "GET", path: "/v1/zones")
    }

    public func getZone(_ zoneId: String) async throws -> WedeResponse<WedeZone> {
        return try await request(method: "GET", path: "/v1/zones/\(zoneId)")
    }

    // Sync
    public func syncBatch(_ batch: WedeSyncBatch) async throws -> [String: Int] {
        return try await request(method: "POST", path: "/v1/sync/batch", body: batch)
    }

    // Connectivity
    public func reportConnectivity(zoneId: String, state: String, channelUsed: String) async throws {
        struct Body: Encodable {
            let zone_id: String
            let state: String
            let channel_used: String
        }
        let _: [String: String] = try await request(
            method: "POST",
            path: "/v1/connectivity/report",
            body: Body(zone_id: zoneId, state: state, channel_used: channelUsed)
        )
    }

    // Parsers
    public func listParsers() async throws -> WedeResponse<[WedeParser]> {
        return try await request(method: "GET", path: "/v1/parsers")
    }

    public func getParser(_ parserId: String) async throws -> WedeResponse<WedeParser> {
        return try await request(method: "GET", path: "/v1/parsers/\(parserId)")
    }

    public func getActiveParser(vertical: String) async throws -> WedeResponse<WedeParser> {
        return try await request(method: "GET", path: "/v1/parsers/vertical/\(vertical)/active")
    }


    // MARK: - Teams

    public func listTeams(tenantId: String? = nil) async throws -> WedeResponse<[WedeTeam]> {
        let path = tenantId != nil ? "/v1/teams?tenant_id=\(tenantId!)" : "/v1/teams"
        return try await request(method: "GET", path: path)
    }

    public func getTeam(_ teamId: String) async throws -> WedeResponse<WedeTeam> {
        return try await request(method: "GET", path: "/v1/teams/\(teamId)")
    }

    public func updateMemberLocation(teamId: String, memberId: String, lat: Double, lng: Double) async throws {
        struct Body: Encodable { let lat: Double; let lng: Double }
        let _: [String: AnyCodable] = try await request(
            method: "PATCH",
            path: "/v1/teams/\(teamId)/members/\(memberId)/location",
            body: Body(lat: lat, lng: lng)
        )
    }

    // MARK: - Dispatch

    public func scoreTeams(lat: Double, lng: Double, vertical: String? = nil, priority: String? = nil) async throws -> WedeResponse<[WedeScoredTeam]> {
        struct Body: Encodable {
            let lat: Double; let lng: Double
            let vertical: String?; let priority: String?
        }
        return try await request(method: "POST", path: "/v1/teams/dispatch/score",
            body: Body(lat: lat, lng: lng, vertical: vertical, priority: priority))
    }

    public func dispatch(eventId: String, teamId: String, notes: String? = nil, eventLat: Double? = nil, eventLng: Double? = nil) async throws -> [String: AnyCodable] {
        struct Body: Encodable {
            let event_id: String; let team_id: String
            let notes: String?; let event_lat: Double?; let event_lng: Double?
        }
        return try await request(method: "POST", path: "/v1/teams/dispatch",
            body: Body(event_id: eventId, team_id: teamId, notes: notes, event_lat: eventLat, event_lng: eventLng))
    }

    // MARK: - Missions

    public func listMissions(teamId: String? = nil, status: MissionStatus? = nil) async throws -> WedeResponse<[WedeMission]> {
        var params: [String] = []
        if let t = teamId { params.append("team_id=\(t)") }
        if let s = status { params.append("status=\(s.rawValue)") }
        let qs = params.isEmpty ? "" : "?" + params.joined(separator: "&")
        return try await request(method: "GET", path: "/v1/missions\(qs)")
    }

    public func getMission(_ missionId: String) async throws -> WedeResponse<WedeMission> {
        return try await request(method: "GET", path: "/v1/missions/\(missionId)")
    }

    public func updateMissionStatus(_ missionId: String, status: MissionStatus) async throws -> WedeResponse<WedeMission> {
        struct Body: Encodable { let status: String }
        return try await request(method: "PATCH", path: "/v1/missions/\(missionId)/status",
            body: Body(status: status.rawValue))
    }

    // MARK: - Catalog

    public func listCatalogActions(vertical: String? = nil) async throws -> [String: AnyCodable] {
        let qs = vertical.map { "?vertical=\($0)" } ?? ""
        return try await request(method: "GET", path: "/v1/catalog/actions\(qs)")
    }

    public func createCatalogAction(vertical: String, code: String, name: String, description: String? = nil) async throws -> [String: AnyCodable] {
        struct Body: Encodable { let vertical: String; let code: String; let name: String; let description: String? }
        return try await request(method: "POST", path: "/v1/catalog/actions",
            body: Body(vertical: vertical, code: code, name: name, description: description))
    }

    public func deleteCatalogAction(_ actionId: String) async throws {
        let _: [String: AnyCodable] = try await request(method: "DELETE", path: "/v1/catalog/actions/\(actionId)")
    }

    // MARK: - Billing

    public func getBilling() async throws -> [String: AnyCodable] {
        return try await request(method: "GET", path: "/v1/tenant/billing")
    }

    // Tenant
    public func getTenantInfo() async throws -> [String: AnyCodable] {
        return try await request(method: "GET", path: "/v1/tenant/me")
    }

    public func getUsage(from: String, to: String) async throws -> [String: AnyCodable] {
        return try await request(method: "GET", path: "/v1/tenant/usage?from=\(from)&to=\(to)")
    }
}
