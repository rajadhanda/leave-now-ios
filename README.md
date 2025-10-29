# Leave Now? iOS App

If I leave right now, what’s the best way to get to my destination?

## Platforms
- iOS 17+ (SwiftUI, Combine, async/await)

## Architecture
```mermaid
graph TD
  A[UI] --> B[Engine]
  B --> C[Services]
  C --> C1[TransitService]
  C --> C2[MapsService]
  C --> C3[WeatherService]
  B --> D[Store]
  D --> D1[TripHistoryStore]
  A --> D
```

## Setup
1. Create `App/Support/Secrets.plist` by copying `App/Support/Secrets.plist.example` and adding your keys.
2. Open the Xcode project (to be generated) and set the bundle identifiers and Signing.
3. Run on iOS 17+.

## Keys
- `TFL_APP_ID`, `TFL_APP_KEY`
- `OPENWEATHER_API_KEY`

## CI
See `.github/workflows/ci.yml`.

## Screenshots
TBD (demo GIF using mocked data).

## Limitations
- No keys in repo. No PII sent off-device. Local-only storage.
