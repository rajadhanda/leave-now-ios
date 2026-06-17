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
- Persist trip outcomes (`OutcomeEvent`/`TripHistoryStore`) and build History.
- Replace the RealtimeTrains placeholder with real endpoint/DTOs.
- Per-leg traffic once a provider emits car legs.

