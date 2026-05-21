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

    // Tenant
    public func getTenantInfo() async throws -> [String: AnyCodable] {
        return try await request(method: "GET", path: "/v1/tenant/me")
    }

    public func getUsage(from: String, to: String) async throws -> [String: AnyCodable] {
        return try await request(method: "GET", path: "/v1/tenant/usage?from=\(from)&to=\(to)")
    }
}
