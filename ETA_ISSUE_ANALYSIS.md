# ETA Longer Than Google Maps - Root Cause Analysis

## Executive Summary

The app consistently shows longer ETAs than Google Maps because:
1. **Right-skewed distribution**: Clamping delays to non-negative values (`max(0, ...)`) creates a right skew, pushing P50 above the base time even when mean delay is 0
2. **Always-on variability padding**: Every transit leg adds random delays via Monte Carlo, even when services are on time
3. **Transfer penalties**: Each transfer adds additional uncertainty padding
4. **P50 vs Expected**: App shows P50 (median), Google Maps likely shows expected/average time

## The Journey

- **Mode**: National Rail + Underground (Tube)
- **No car routes involved**

## Calculation Flow

### Step 1: Base ETA
```swift
// RecommenderV2.swift:90
let base = estimator.baseETA(minutesForLegs: plan.legs.map { $0.durationMinutes })
```
- Uses durations from TfL API directly (journey leg `duration` is already in
  minutes; no unit conversion happens or is needed)
- These may already include realistic padding

### Step 2: Monte Carlo Simulation

#### Baseline Variability (Always Added)
For a National Rail + Underground journey:

```swift
// RecommenderV2.swift:48-52
case .tube: priors.append(DelayPrior(meanMin: 0.0, stdMin: 1.0))
case .nationalRail: priors.append(DelayPrior(meanMin: 0.0, stdMin: 3.0))
```

**The Problem**: Even though `meanMin = 0.0`, the Monte Carlo simulation adds variability:

```swift
// UncertaintyModel.swift:25
delay += max(0, p.meanMin + z0 * p.stdMin)
```

#### The Right-Skew Bug

When `meanMin = 0.0` and `stdMin > 0`:
- Normal distribution samples both positive and negative values
- Negative delays are clamped to 0 (`max(0, ...)`)
- This creates a **right-skewed distribution**:
  - ~50% of samples = 0 (clamped negatives)
  - ~50% of samples > 0 (positive delays)
- **Result**: P50 (median) is pushed ABOVE the base time, even when mean=0

**Example**:
- Base: 30 minutes
- Tube leg: mean=0, std=1.0
- National Rail: mean=0, std=3.0
- After 500 Monte Carlo samples, P50 ≈ 32-33 minutes (above base!)

#### Transfer Penalties

```swift
// RecommenderV2.swift:84-86
if plan.changes > 0 {
    priors.append(DelayPrior(meanMin: 0.0, stdMin: Double(plan.changes) * 1.0))
}
```

Even 1 transfer adds more uncertainty padding.

## Why Google Maps is Shorter

1. **Shows Expected Time**: Google Maps likely shows the **mean/expected** travel time, which for this app would be closer to base time (when mean=0)

2. **No Conservative Padding**: Google Maps doesn't add Monte Carlo uncertainty padding

3. **Historical Data**: Google Maps uses vast historical data to show realistic expected times

4. **Different Philosophy**: 
   - Google Maps: "This is how long it typically takes"
   - This App: "This is the median time accounting for uncertainty"

## Specific Issues

### Issue 1: Right-Skewed Distribution
**Location**: `UncertaintyModel.swift:25`

```swift
delay += max(0, p.meanMin + z0 * p.stdMin)
```

**Problem**: Clamping to 0 creates right skew, inflating P50

**Fix Options**:
1. Don't clamp (allow negative delays in simulation, clamp only final result)
2. Use a different distribution (e.g., log-normal for positive-only)
3. Adjust base calculation to account for the skew

### Issue 2: Always-On Variability
**Location**: `RecommenderV2.swift:48-52`

Every leg adds variability even when services are running perfectly on time.

**Fix Options**:
1. Only add variability when delays are detected (from real-time data)
2. Reduce baseline std dev values
3. Make variability conditional on actual service status

### Issue 3: Transfer Penalties Always Applied
**Location**: `RecommenderV2.swift:84-86`

Even single transfers add uncertainty padding.

**Fix Options**:
1. Only apply transfer penalties when connections are tight
2. Reduce the per-transfer std dev
3. Make it conditional on connection times

### Issue 4: TfL Durations May Already Include Padding
**Location**: `TflTransitService.swift:82`

TfL API durations may already account for typical delays, then Monte Carlo adds MORE padding.

**Investigation Needed**: Check if TfL API durations are:
- Scheduled time (no padding)
- Realistic time (includes typical delays)
- Best-case time

## Recommended Fixes (Priority Order)

### 1. Fix Right-Skew Bug (High Priority)
Change `UncertaintyModel.swift` to not clamp intermediate delays:

```swift
// Current:
delay += max(0, p.meanMin + z0 * p.stdMin)

// Proposed:
delay += p.meanMin + z0 * p.stdMin
// Then clamp final result: max(0, baseMinutes + delay)
```

This ensures P50 aligns with mean when mean=0.

### 2. Reduce Baseline Variability (Medium Priority)
Reduce std dev values, especially for tube:

```swift
case .tube: priors.append(DelayPrior(meanMin: 0.0, stdMin: 0.5))  // Was 1.0
case .nationalRail: priors.append(DelayPrior(meanMin: 0.0, stdMin: 2.0))  // Was 3.0
```

### 3. Make Variability Conditional (Medium Priority)
Only add variability when real-time delays are detected, or reduce when services are on time.

### 4. Investigate TfL Duration Basis (Low Priority)
Determine what TfL API durations represent and adjust base calculation accordingly.

## Example Calculation (Current vs Fixed)

**Route**: National Rail (20 min) → Underground (15 min)

### Current (Broken):
- Base: 35 minutes
- National Rail: mean=0, std=3.0 → samples: [-3, 0, +3, +1.5, ...] → clamped: [0, 0, +3, +1.5, ...]
- Tube: mean=0, std=1.0 → samples: [-1, +1, 0, +0.5, ...] → clamped: [0, +1, 0, +0.5, ...]
- **P50**: ~37 minutes (inflated!)

### Fixed (No Clamp on Intermediates):
- Base: 35 minutes  
- National Rail: mean=0, std=3.0 → samples: [-3, 0, +3, +1.5, ...]
- Tube: mean=0, std=1.0 → samples: [-1, +1, 0, +0.5, ...]
- Total delay: [-4, +1, +3, +2, ...]
- **P50**: ~35 minutes (matches base when mean=0)

## Testing Recommendations

1. Compare P50 vs base time when no disruptions present (should be close)
2. Add logging to show actual delay distributions
3. Compare with Google Maps for same routes at same times
4. Validate that mean of Monte Carlo samples ≈ base when mean delay = 0

