# Leave Now? — Commute Decision Engine (iOS)

**Purpose:** Provide confident, low-friction, personalised recommendations on **when to leave** and **which familiar route to take**, based on current conditions, routine patterns, and journey stability. We solve **timing confidence**, not navigation.


## Core Screens

- **Primary (active open):** One recommendation card (P50, P90, confidence, rationale) + optional fallback.

- **Passive (notification):** “Leave now / wait / switch” with one-line reason.

## Build

The Xcode project is generated from [`project.yml`](project.yml) with
[XcodeGen](https://github.com/yonaskolb/XcodeGen) — it is **not** committed.

```sh
brew install xcodegen
cp App/Support/Secrets.plist.example App/Support/Secrets.plist   # then add your keys
xcodegen generate
open LeaveNow.xcodeproj
```

- iOS 17+, SwiftUI, async/await, Combine

- Services: TfL Unified API (journeys + disruptions), Apple MapKit (walking ETA), OpenWeather

- Engine: ETA estimator + Monte Carlo uncertainty + utility scoring

- Storage: Core Data or SQLite (trip outcomes + calibration)

- Privacy: On-device; no analytics; secrets via `Secrets.plist` (not in repo)

See [`PRODUCT_CHARTER.md`](PRODUCT_CHARTER.md) for the product doctrine.

### National Rail (UK) Integration

This app can enrich rail legs with platform + basic service timing via a pluggable provider.

- Default: **disabled** (no provider).
- Optional: **Realtime Trains** — add `REALTIMETRAINS_BASE_URL` and `REALTIMETRAINS_API_KEY` to `Info.plist` (consumed via `Secrets.plist` at build).
- Fallbacks (future): Darwin OpenLDBWS or TransportAPI can implement `NationalRailService` without changing the rest of the app.

> Note: The current RTT implementation is a tolerant placeholder; update endpoint paths and DTO keys once you have provider docs.
