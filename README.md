# WedeSDK for Swift

Official Swift SDK for the Wede Technology platform.

Wede is an offline-first infrastructure layer that keeps critical digital services operational when connectivity, cloud, or infrastructure fails.

## Requirements

- iOS 15+ / macOS 12+
- Swift 5.9+

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Wedeadmin/wede-sdk-swift.git", from: "0.1.0")
]
```

## Quick Start

```swift
import WedeSDK

let client = WedeClient(apiKey: "wede_live_YOUR_KEY")

// Send an event
let event = WedeEvent(
    type: "EMERGENCY",
    idempotencyKey: "evt-001",
    payload: ["patient_id": AnyCodable("PT123")],
    vertical: "healthcare",
    priority: "critical"
)

let result = try await client.sendEvent(event)

// List zones
let zones = try await client.listZones()

// Get active parser for vertical
let parser = try await client.getActiveParser(vertical: "healthcare")

// Sync offline batch
let batch = WedeSyncBatch(
    events: [event],
    capturedAt: ISO8601DateFormatter().string(from: Date()),
    deviceId: "device-001"
)
let syncResult = try await client.syncBatch(batch)
```

## Methods

| Method | Description |
|--------|-------------|
| `sendEvent(_:)` | Submit a new event |
| `listEvents(zoneId:vertical:)` | List events |
| `listZones()` | List all zones |
| `getZone(_:)` | Get a specific zone |
| `syncBatch(_:)` | Sync offline batch |
| `reportConnectivity(zoneId:state:channelUsed:)` | Report connectivity state |
| `listParsers()` | List parsers |
| `getParser(_:)` | Get a specific parser |
| `getActiveParser(vertical:)` | Get active parser for vertical |
| `getTenantInfo()` | Get tenant details |
| `getUsage(from:to:)` | Get usage statistics |

## Documentation

https://docs.wede.pt

## License

MIT
