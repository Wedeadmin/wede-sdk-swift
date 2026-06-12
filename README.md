# WedeSDK (Swift)

Official Swift SDK for the Wede Technology platform. Supports iOS 15+ and macOS 12+.

Wede is an offline-first middleware layer that keeps critical operational workflows running regardless of connectivity. When internet fails, operations continue locally and sync automatically on reconnect.

## Installation

### Swift Package Manager

Add to `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Wedeadmin/wede-sdk-swift.git", from: "1.2.0")
]
```

Or in Xcode: File > Add Packages > enter the repository URL.

## Quick Start

```swift
import WedeSDK

let client = WedeClient(apiKey: "wede_live_YOUR_KEY")

// Register device on first launch
let deviceId = WedeDeviceId.getOrCreate()
try await client.registerDevice(
    deviceId: deviceId,
    platform: "ios",
    appVersion: "2.0.0"
)

// Send an event
let event = try await client.sendEvent(
    type: "EMERGENCY",
    priority: "high",
    vertical: "healthcare",
    idempotencyKey: UUID().uuidString,
    payload: ["condition": "cardiac_arrest"],
    lat: 38.7169, lng: -9.1395
)

// Score and dispatch teams
let scored = try await client.scoreTeams(
    lat: 38.7169, lng: -9.1395,
    vertical: "healthcare", priority: "high"
)

try await client.dispatch(
    eventId: event.data.eventId,
    teamId: scored.data[0].teamId,
    eventLat: 38.7169, eventLng: -9.1395
)
```

## Offline Operation

The SDK operates fully offline using a local score engine identical to the backend. Dispatches are queued with guaranteed delivery.

```swift
// Offline dispatch — queued if no connectivity
let result = try await client.dispatch(
    eventId: "uuid", teamId: "uuid",
    eventLat: 38.7169, eventLng: -9.1395
)
// result.queued == true when offline

// Sync when connectivity restored
try await client.syncDeviceQueue(deviceId: deviceId)

// Refresh local team and catalog cache
try await client.refreshCache()

// Request backup for active mission
try await client.requestBackup(
    missionId: "uuid",
    eventId: "uuid",
    eventLat: 38.7169,
    eventLng: -9.1395
)

// Update dispatch settings
try await client.updateDispatchSettings(
    dispatchMode: true,
    dispatchThreshold: 0.20,
    reinforcementTimeoutMin: 10
)
```

## Method Reference

| Method | Description |
| --- | --- |
| `sendEvent(...)` | Submit an operational event |
| `listEvents()` | List events for the tenant |
| `scoreTeams(...)` | Score available teams by proximity and capability |
| `dispatch(...)` | Dispatch a team to an event |
| `requestBackup(...)` | Request backup for an active mission |
| `listMissions()` | List missions |
| `getMission(id)` | Get a specific mission |
| `updateMissionStatus(id, status)` | Update mission status |
| `updateDispatchSettings(...)` | Configure auto-dispatch settings |
| `registerDevice(deviceId, platform, appVersion)` | Register device for offline sync |
| `syncDeviceQueue(deviceId)` | Sync offline queue with server |
| `refreshCache()` | Refresh local team and catalog cache |
| `getTenantInfo()` | Get tenant configuration |
| `getUsage(from, to)` | Get usage statistics |
| `listZones()` | List operational zones |
| `listParsers()` | List event parsers |
| `getBilling()` | Get billing information |

## Requirements

- iOS 15+ / macOS 12+
- Swift 5.7+
- Xcode 14+

## Documentation

[docs.wede.pt](https://docs.wede.pt)

## Patent

Wede Technology INPI 120488 (pending) — Claim 5: local score engine and guaranteed offline dispatch queue.

## License

MIT
