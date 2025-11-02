# ETA Calculation Breakdown

## Overview

The app calculates travel time estimates using a **base ETA + Monte Carlo uncertainty simulation** approach. This is different from Google Maps, which typically uses real-time traffic data and historical travel patterns.

## Calculation Flow

### Step 1: Base ETA Calculation
**Location:** `ETAEstimator.swift`

```swift
baseETA(minutesForLegs: [Int]) -> Int
```

- Simply sums all leg durations: `minutesForLegs.reduce(0, +)`
- No variability added at this stage
- Uses theoretical/scheduled durations for each leg

### Step 2: Weather Penalty
**Location:** `ETAEstimator.swift`

```swift
applyWeatherPenalty(walkMinutes: Int, rainIntensity: Double?, k: Double) -> Int
```

- Adds extra time for walking in rain
- Formula: `walkMinutes * k * rainIntensity` (where rainIntensity is 0.0-1.0)
- Only affects walking legs, not transit legs
- Returns additional minutes to add to base ETA

### Step 3: Monte Carlo Uncertainty Simulation
**Location:** `UncertaintyModel.swift` ? `RecommenderV2.swift`

Uses **500 Monte Carlo samples** to estimate P50 (median) and P90 (90th percentile) travel times.

#### Baseline Variability (per leg)
Each transit leg adds a random delay sampled from a normal distribution:

| Mode | Mean (minutes) | Std Dev (minutes) | Notes |
|------|----------------|-------------------|-------|
| Tube | 0.0 | 1.0 | Low variability |
| Bus | 0.0 | 2.0 | Higher variability |
| Overground | 0.0 | 1.5 | Medium variability |
| DLR | 0.0 | 1.0 | Low variability |
| National Rail | 0.0 | 3.0 | Highest variability |

#### Transfer Penalty
- Each transfer/change adds variability: `stdMin = changes * 1.0`
- More changes = more uncertainty

#### Disruption Penalties
Based on disruption severity:

| Severity | Mean Delay (min) | Std Dev (min) |
|----------|------------------|---------------|
| Minor | 2.0 | 1.0 |
| Moderate | 5.0 | 2.0 |
| Severe | 10.0 | 5.0 |

#### Monte Carlo Process
1. For each of 500 samples:
   - Start with base ETA + weather penalty
   - For each leg, sample a random delay from normal distribution
   - Add transfer variability
   - Add disruption delays
   - Sum all delays
2. Sort all 500 total times
3. **P50** = median (sample at index 250)
4. **P90** = 90th percentile (sample at index 450)

### Final Output
- **P50 (median)**: Expected travel time (50% chance of arriving in this time or less)
- **P90 (worst case)**: Conservative estimate (90% chance of arriving in this time or less)
- **Confidence**: `1.0 - (p90 - p50) / 50.0` (clamped to 0.0-1.0)

## Why Google Maps May Show Shorter Times

### 1. **Real-Time Traffic Data**
- Google Maps uses live traffic conditions from millions of users
- This app uses **theoretical leg durations** without real-time traffic for cars
- Google can account for current road congestion, accidents, road closures

### 2. **Historical Pattern Data**
- Google has vast historical data showing typical travel times for routes at specific times
- This app uses fixed variability estimates, not learned historical patterns

### 3. **Conservative Padding**
- This app adds **pessimistic uncertainty padding** (P90 estimates)
- Google Maps typically shows **expected/average** travel times (closer to P50)
- The baseline variability (stdMin) adds extra padding even without disruptions

### 4. **Aggressive Disruption Modeling**
- Even "minor" disruptions add +2 minutes mean delay
- The Monte Carlo simulation can compound these delays across multiple legs

### 5. **No Real-Time Optimization**
- Google Maps can suggest alternate routes in real-time based on current conditions
- This app uses pre-calculated route options without live re-routing

## Example Calculation

**Route:** Walking (5 min) ? Tube (20 min) ? Walking (3 min)

1. **Base ETA**: 5 + 20 + 3 = 28 minutes
2. **Weather**: Light rain (0.3 intensity), k=0.5 ? Penalty: 5?0.5?0.3 = 0.75 ? +1 minute
3. **Base + Weather**: 29 minutes
4. **Variability Added** (per Monte Carlo sample):
   - Walk leg 1: 0 (no variability)
   - Tube leg: Random ~N(0, 1?) ? e.g., +1.2 min
   - Walk leg 2: 0 (no variability)
   - Transfer penalty: 0 (no transfers in this case)
5. **Final Sample**: 29 + 1.2 = 30.2 minutes
6. **After 500 samples**: P50 = 30 min, P90 = 33 min

**Result:** ETA shows 30 min (P50) and worst case 33 min (P90), while Google Maps might show 28-29 minutes (their expected time without the conservative padding).
