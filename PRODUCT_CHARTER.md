# PRODUCT CHARTER — Leave Now?

## Purpose

Provide commuters with confident, low-friction, personalised recommendations on **when to leave** and **which familiar route to take**, based on current conditions, routine patterns, and journey stability — without route exploration or maps.

## Problem We Solve

Transit apps list routes and ETAs but do not answer:

- Should I leave now or wait?

- How reliable is my usual route today?

- How likely am I to arrive late?

We replace uncertainty with predictive confidence.

## Target User

Urban commuters with consistent patterns who already know their route, care about reliability, and want to avoid re-evaluating their commute daily.

## Core Value

**Zero-decision commuting.** The app tells you when to leave with confidence.

## Modes

- **Primary (Passive / Proactive):** Detect likely pre-departure window → notify: leave now / wait / switch to fallback.

- **Secondary (Active / On-Demand):** Open app → see a single recommendation (P50, P90, confidence, fallback, rationale).

No maps. No multi-option lists. No navigation UI.

## Differentiators

See README table. We solve **timing confidence**, not discovery.

## Outcome-Based Feedback (with Route Compliance Detection)

Structured calibration only; no text opinions.

**Auto-capture per commute:**

- `recommended_departure_time`, `actual_departure_time`

- `recommended_route_fingerprint`, `actual_route_fingerprint`

- `predicted_arrival_P50`, `predicted_arrival_P90`

- `actual_trip_duration`

**One-tap post-trip:**

- If followed route: `[ Earlier ] [ As Expected ] [ Later ]`

- If not followed: `[ Intentional ] [ Unintentional ]`

Enables calibration of walking/transfer times, reliability priors, risk weighting, and future ML/LLM layers.

## Non-Goals

No maps, route comparison, turn-by-turn, carriage/exit guidance, social features, or opinion capture.

## Success Metrics

- Median regret decreases over time

- “As Expected” ≥ 60% after 2 weeks calibration

- Low notification dismissal

- Daily habit with minimal interaction

## Long-Term Vision

Calibrated data enables ML-based stability predictions and LLM disruption interpretation for structured effects.


