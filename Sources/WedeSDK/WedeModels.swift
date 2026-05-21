import Foundation

public struct WedeEvent: Codable {
    public let type: String
    public let idempotencyKey: String
    public let payload: [String: AnyCodable]
    public var priority: String?
    public var vertical: String?
    public var zoneId: String?
    public var channelPreference: String?

    public init(
        type: String,
        idempotencyKey: String,
        payload: [String: AnyCodable],
        priority: String? = nil,
        vertical: String? = nil,
        zoneId: String? = nil,
        channelPreference: String? = nil
    ) {
        self.type = type
        self.idempotencyKey = idempotencyKey
        self.payload = payload
        self.priority = priority
        self.vertical = vertical
        self.zoneId = zoneId
        self.channelPreference = channelPreference
    }

    enum CodingKeys: String, CodingKey {
        case type
        case idempotencyKey = "idempotency_key"
        case payload
        case priority
        case vertical
        case zoneId = "zone_id"
        case channelPreference = "channel_preference"
    }
}

public struct WedeZone: Codable {
    public let zoneId: String
    public let name: String
    public let country: String
    public let region: String?
    public let connectivityState: String
    public let verticalsActive: [String]

    enum CodingKeys: String, CodingKey {
        case zoneId = "zone_id"
        case name, country, region
        case connectivityState = "connectivity_state"
        case verticalsActive = "verticals_active"
    }
}

public struct WedeSyncBatch: Codable {
    public let events: [WedeEvent]
    public let capturedAt: String
    public var deviceId: String?

    public init(events: [WedeEvent], capturedAt: String, deviceId: String? = nil) {
        self.events = events
        self.capturedAt = capturedAt
        self.deviceId = deviceId
    }

    enum CodingKeys: String, CodingKey {
        case events
        case capturedAt = "captured_at"
        case deviceId = "device_id"
    }
}

public struct WedeParserField: Codable {
    public let id: String
    public let name: String
    public let smsCode: String
    public let type: String
    public let required: Bool
    public let enabled: Bool
    public let offlineCapable: Bool
    public let section: String
    public let maxBytes: Int
    public var description: String?
    public var enumValues: [String]?
    public var legal: Bool?

    enum CodingKeys: String, CodingKey {
        case id, name, type, required, enabled, section, description, legal
        case smsCode = "sms_code"
        case offlineCapable = "offline_capable"
        case maxBytes = "max_bytes"
        case enumValues = "enum_values"
    }
}

public struct WedeParser: Codable {
    public let id: String
    public let tenantId: String
    public let vertical: String
    public let version: Int
    public let name: String
    public let isActive: Bool
    public let schema: [WedeParserField]
    public let createdAt: String
    public let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, vertical, version, name, schema
        case tenantId = "tenant_id"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

public struct WedeResponse<T: Codable>: Codable {
    public let data: T
    public let requestId: String?

    enum CodingKeys: String, CodingKey {
        case data
        case requestId = "request_id"
    }
}

// AnyCodable for flexible payload
public struct AnyCodable: Codable {
    public let value: Any

    public init(_ value: Any) { self.value = value }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(Bool.self) { value = v }
        else if let v = try? container.decode(Int.self) { value = v }
        else if let v = try? container.decode(Double.self) { value = v }
        else if let v = try? container.decode(String.self) { value = v }
        else if let v = try? container.decode([String: AnyCodable].self) { value = v }
        else if let v = try? container.decode([AnyCodable].self) { value = v }
        else { value = NSNull() }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let v as Bool: try container.encode(v)
        case let v as Int: try container.encode(v)
        case let v as Double: try container.encode(v)
        case let v as String: try container.encode(v)
        case let v as [String: AnyCodable]: try container.encode(v)
        case let v as [AnyCodable]: try container.encode(v)
        default: try container.encodeNil()
        }
    }
}
