# Plan

## Assumptions
- London-only v1; TfL as transit source.
- Deterministic engine v1, Monte Carlo v2; no LLMs.

## Trade-offs
- Simplicity over full coverage; accurate-enough priors.

## Next Steps
- Implement services and DTOs.
- Deterministic engine with unit tests.
- Add uncertainty model and scoring.

## Progress (hardening pass)
- Secrets: single source of truth (`Secrets.plist` via `SecretsStore`);
  blank values read as absent; Info.plist carries bundle keys only; TfL
  `app_id` dropped.
- Dev loop: MOCK_DATA=YES short-circuits to deterministic mock data; sample
  banners distinguish mock mode / keys missing / services failed.
- Line identity: `lineId` decoded from TfL `lineIdentifier.id` (canonical,
  for disruption matching + fingerprints), `lineName` for display.
- RealtimeTrains: rewritten against the next-gen data.rtt.io API (Bearer
  token, `/rtt/location` with `filterTo`, ISO-8601 times); dev-only per RTT
  terms, off without a token.
- Traffic: shelved behind `AppConfig.trafficEnabled = false` until car legs
  exist.
- Confidence/rain: one `ConfidenceModel` for score/level/"stable variance";
  rain penalty recalibrated (sqrt curve, k=0.5 -> ~+2m light / ~+4m heavy on
  a 10-minute walk).
- Background: never requests notification authorization off a background
  task; schedules only when already authorized.
- Outcome loop: PendingTrip capture on recommend, "I've left"/"I've arrived"
  actuals, one-tap structured feedback, persistent JSON store, real History
  screen, `OutcomeCalibrator` seam for future prior adjustment.
- Hygiene: shared severity-rank + traffic-level helpers, cached formatters,
  one plain TfL decoder, same-line legs no longer counted as changes,
  recommendation TTL cache guarding TfL/RTT rate limits; LocationService
  removed (postcode origins only in v1).

## Progress
- Live path: TfL journeys + line-status disruptions, OpenWeather rain, optional
  RealtimeTrains/traffic enrichment, Monte-Carlo ETA, utility scoring.
- Decision engine: `DepartureDecider` turns P90 + an optional "arrive by" into
  leave-now / leave-in-N / wait / take-fallback.
- UI: tabbed app; editable trip + arrive-by; reachable Settings with working
  scoring-weight sliders; fallback route expansion; explicit "sample data" state
  on failure (no more silently presenting mock data as live).
- Notifications: local "time to leave" reminder + a background-refresh task
  (basic; needs on-device verification).
- Project is generated from `project.yml` via XcodeGen (no committed .xcodeproj).

## Next
- On-device verification of background refresh + notification delivery.
- Implement `OutcomeCalibrator` (adjust priors from stored outcomes).
- Optional: `/rtt/service` follow-up call for exact intermediate arrivals.
- Per-leg traffic once a provider emits car legs (flip `trafficEnabled`).

