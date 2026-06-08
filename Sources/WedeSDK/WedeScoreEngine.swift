import Foundation

/**
 * Wede Proximity Score Engine — Swift SDK
 * Identical algorithm to backend scoreEngine.ts and JS/RN/Android SDKs.
 * No external dependencies. Pure Swift. Works fully offline.
 * Patent INPI 120488 — Claim 5: local scoring without connectivity.
 */

public struct GeoPoint: Codable {
    public let lat: Double
    public let lng: Double
    public init(lat: Double, lng: Double) { self.lat = lat; self.lng = lng }
}

public struct TeamMemberInput: Codable {
    public let id: String
    public let status: String
    public let lat: Double?
    public let lng: Double?
    public let lastSeen: String?
    enum CodingKeys: String, CodingKey {
        case id, status, lat, lng
        case lastSeen = "last_seen"
    }
}

public struct TeamEquipmentInput: Codable {
    public let code: String
    public let status: String
}

public struct TeamVerticalInput: Codable {
    public let vertical: String
    public let eventTypes: [String]
    enum CodingKeys: String, CodingKey {
        case vertical
        case eventTypes = "event_types"
    }
}

public struct TeamInput: Codable {
    public let id: String
    public let name: String
    public let status: String
    public let vertical: String
    public let equipment: [String]
    public let zoneLat: Double?
    public let zoneLng: Double?
    public let zoneBoundary: [GeoPoint]?
    public let members: [TeamMemberInput]
    public let verticals: [TeamVerticalInput]?
    public let teamEquipment: [TeamEquipmentInput]?
    enum CodingKeys: String, CodingKey {
        case id, name, status, vertical, equipment, members, verticals
        case zoneLat = "zone_lat"
        case zoneLng = "zone_lng"
        case zoneBoundary = "zone_boundary"
        case teamEquipment = "team_equipment"
    }
}

public struct EventInput: Codable {
    public let lat: Double
    public let lng: Double
    public let vertical: String?
    public let eventType: String?
    public let priority: String?
    public let requiredEquipment: [String]?
    public init(lat: Double, lng: Double, vertical: String? = nil, eventType: String? = nil,
                priority: String? = nil, requiredEquipment: [String]? = nil) {
        self.lat = lat; self.lng = lng; self.vertical = vertical
        self.eventType = eventType; self.priority = priority
        self.requiredEquipment = requiredEquipment
    }
    enum CodingKeys: String, CodingKey {
        case lat, lng, vertical, priority
        case eventType = "event_type"
        case requiredEquipment = "required_equipment"
    }
}

public struct TeamPosition: Codable {
    public let lat: Double
    public let lng: Double
    public let source: String
    public let lastSeen: String?
}

public struct ScoredTeam: Codable {
    public let teamId: String
    public let teamName: String
    public let status: String
    public let vertical: String
    public let distanceKm: Double
    public let etaMin: Int
    public let equipmentMatch: Double
    public let memberAvailability: Double
    public let score: Double
    public let recommended: Bool
    public let channel: String
    public let position: TeamPosition
}

public enum ScoreEngine {

    public static func haversineKm(_ lat1: Double, _ lng1: Double, _ lat2: Double, _ lng2: Double) -> Double {
        let R = 6371.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLng = (lng2 - lng1) * .pi / 180
        let a = pow(sin(dLat / 2), 2) +
            cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) * pow(sin(dLng / 2), 2)
        return R * 2 * atan2(sqrt(a), sqrt(1 - a))
    }

    public static func pointInPolygon(_ lat: Double, _ lng: Double, polygon: [GeoPoint]) -> Bool {
        guard polygon.count >= 3 else { return false }
        var inside = false
        let n = polygon.count
        var j = n - 1
        for i in 0..<n {
            let xi = polygon[i].lng, yi = polygon[i].lat
            let xj = polygon[j].lng, yj = polygon[j].lat
            let intersect = ((yi > lat) != (yj > lat)) &&
                (lng < (xj - xi) * (lat - yi) / (yj - yi) + xi)
            if intersect { inside = !inside }
            j = i
        }
        return inside
    }

    private static func resolvePosition(_ team: TeamInput) -> TeamPosition {
        let now = Date()
        let tenMin: TimeInterval = 10 * 60
        let fmt = ISO8601DateFormatter()

        let fresh = team.members
            .filter { m in m.status == "available" && m.lat != nil && m.lng != nil && m.lastSeen != nil }
            .filter { m in
                guard let ls = m.lastSeen, let date = fmt.date(from: ls) else { return false }
                return now.timeIntervalSince(date) < tenMin
            }
            .max { a, b in
                let da = fmt.date(from: a.lastSeen ?? "") ?? .distantPast
                let db = fmt.date(from: b.lastSeen ?? "") ?? .distantPast
                return da < db
            }

        if let f = fresh, let lat = f.lat, let lng = f.lng {
            return TeamPosition(lat: lat, lng: lng, source: "gps", lastSeen: f.lastSeen)
        }

        if let any = team.members.first(where: { $0.lat != nil && $0.lng != nil }),
           let lat = any.lat, let lng = any.lng {
            return TeamPosition(lat: lat, lng: lng, source: "gps", lastSeen: any.lastSeen)
        }

        if let zoneLat = team.zoneLat, let zoneLng = team.zoneLng {
            return TeamPosition(lat: zoneLat, lng: zoneLng, source: "zone", lastSeen: nil)
        }

        return TeamPosition(lat: 0, lng: 0, source: "unknown", lastSeen: nil)
    }

    private static func resolveChannel(etaMin: Int, priority: String?) -> String {
        if priority == "P1_CRITICAL" || priority == "CRITICAL" {
            return etaMin > 5 ? "sms" : "internet"
        }
        return etaMin > 15 ? "sms" : "internet"
    }

    public static func scoreTeams(_ teams: [TeamInput], evt: EventInput) -> [ScoredTeam] {
        let available = teams.filter { $0.status == "available" || $0.status == "on_mission" }

        var scored: [ScoredTeam] = available.map { team in
            let pos = resolvePosition(team)
            let distanceKm = pos.source != "unknown"
                ? (haversineKm(pos.lat, pos.lng, evt.lat, evt.lng) * 100).rounded() / 100
                : 0.0
            let etaMin = Int((distanceKm / 0.7).rounded())

            let memberAvail = team.members.isEmpty ? 0.0 :
                Double(team.members.filter { $0.status == "available" }.count) / Double(team.members.count)

            let operationalEquip = team.teamEquipment?
                .filter { $0.status == "operational" }.map { $0.code } ?? team.equipment
            let required = evt.requiredEquipment ?? []
            let equipmentMatch: Double
            if !required.isEmpty {
                equipmentMatch = Double(required.filter { operationalEquip.contains($0) }.count) / Double(required.count)
            } else {
                equipmentMatch = operationalEquip.isEmpty ? 0.5 : 0.8
            }

            let inZone = team.zoneBoundary.map { pointInPolygon(evt.lat, evt.lng, polygon: $0) } ?? true
            let geofencePenalty = inZone ? 0.0 : 0.2

            let coversVertical = evt.vertical == nil || team.vertical == evt.vertical ||
                (team.verticals?.contains { $0.vertical == evt.vertical } ?? false)
            let coversEventType = evt.eventType == nil ||
                (team.verticals?.contains { $0.eventTypes.contains(evt.eventType!) } ?? true)
            let capabilityBonus = (coversVertical && coversEventType) ? 0.0 : 0.3

            let travelScore = min(Double(etaMin) / 30.0, 1.0)
            let capScore = (1 - equipmentMatch) + capabilityBonus
            let memberScore = 1 - memberAvail
            let loadPenalty = team.status == "on_mission" ? 0.5 : 0.0
            let finalScore = (0.35 * travelScore) + (0.25 * capScore) +
                (0.2 * memberScore) + (0.1 * loadPenalty) + (0.1 * geofencePenalty)

            return ScoredTeam(
                teamId: team.id, teamName: team.name, status: team.status, vertical: team.vertical,
                distanceKm: distanceKm, etaMin: etaMin,
                equipmentMatch: (equipmentMatch * 100).rounded() / 100,
                memberAvailability: (memberAvail * 100).rounded() / 100,
                score: (finalScore * 10000).rounded() / 10000,
                recommended: false,
                channel: resolveChannel(etaMin: etaMin, priority: evt.priority),
                position: pos
            )
        }

        scored.sort { $0.score > $1.score }
        if !scored.isEmpty {
            let top = scored[0]
            scored[0] = ScoredTeam(
                teamId: top.teamId, teamName: top.teamName, status: top.status,
                vertical: top.vertical, distanceKm: top.distanceKm, etaMin: top.etaMin,
                equipmentMatch: top.equipmentMatch, memberAvailability: top.memberAvailability,
                score: top.score, recommended: true, channel: top.channel, position: top.position
            )
        }
        return scored
    }
}
