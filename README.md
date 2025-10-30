# Leave Now? — Commute Decision Engine (iOS)

**Purpose:** Provide confident, low-friction, personalised recommendations on **when to leave** and **which familiar route to take**, based on current conditions, routine patterns, and journey stability. We solve **timing confidence**, not navigation.

## Differentiation (vs Citymapper / Google Maps)

| Feature | Citymapper / Google | Leave Now? |

| --- | --- | --- |

| Route exploration | ✅ | ❌ Out of scope |

| Carriage / exits | ✅ | ❌ Out of scope |

| Platform numbers | ✅ | ✅ (only when relevant) |

| Weather-adjusted walking | ❌ | ✅ |

| Reliability / variance (P50/P90) | ❌ | **✅ Core** |

| Personal walking/transfer calibration | ❌ | **✅ Learns** |

| Proactive “leave now” timing | ❌ | **✅ Primary** |

## Core Screens

- **Primary (active open):** One recommendation card (P50, P90, confidence, rationale) + optional fallback.

- **Passive (notification):** “Leave now / wait / switch” with one-line reason.

## Build

- iOS 17+, SwiftUI, async/await, Combine

- Services: TfL Unified API (journeys + disruptions), Apple MapKit (walking ETA), OpenWeather

- Engine: ETA estimator + Monte Carlo uncertainty + utility scoring

- Storage: Core Data or SQLite (trip outcomes + calibration)

- Privacy: On-device; no analytics; secrets via `Secrets.plist` (not in repo)

See [`PRODUCT_CHARTER.md`](PRODUCT_CHARTER.md) for the product doctrine.
