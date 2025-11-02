# ETA Calculation Breakdown

## Overview
This document explains how the app calculates ETA (P50) and worst-case travel time (P90), and why Google Maps typically predicts shorter times.

## Calculation Flow

### 1. Base ETA Calculation (`ETAEstimator.swift`)
- **Method**: Sum of all leg durations from the journey plan
- **Source**: TfL Unified API provides scheduled durations for each leg (walking, tube, bus, overground, DLR, national rail)
- **Formula**: `baseETA = ?(durationMinutes for each leg)`

### 2. Weather Penalty (`ETAEstimator.swift`)
- Applied only to walking portions
- **Formula**: `penalty = walkMinutes ? k ? rainIntensity`
  - `k` = rain sensitivity coefficient (default: 0.08 from UserPrefs)
  - `rainIntensity` = precipitation in mm/hour (capped between 0.0 and 1.0)
- **Example**: 10 min walk with 0.5 mm/hr rain = 10 ? 0.08 ? 0.5 = 0.4 min ? 0 min
- **Example**: 20 min walk with 5 mm/hr rain = 20 ? 0.08 ? 1.0 = 1.6 min ? 2 min

### 3. Baseline Uncertainty Priors (`RecommenderV2.swift`)
For each non-walking leg, a small variability is added to account for typical delays:
- **Tube**: mean=0, std=1.0 min
- **Bus**: mean=0, std=2.0 min  
- **Overground**: mean=0, std=1.5 min
- **DLR**: mean=0, std=1.0 min
- **National Rail**: mean=0, std=3.0 min (most variable)
- **Transfers**: std = 1.0 ? number of changes

### 4. Disruption Delays (`RecommenderV2.swift`)
If disruptions are present, additional delay priors are added:
- **Minor disruption**: mean=2 min, std=1 min
- **Moderate disruption**: mean=5 min, std=2 min
- **Severe disruption**: mean=10 min, std=5 min

### 5. Monte Carlo Simulation (`UncertaintyModel.swift`)
- **Samples**: 500 simulations
- **Method**: Box-Muller transform to generate normal distribution samples
- **Process**:
  1. Start with: `baseMinutes + rainDelta`
  2. For each prior, sample a delay: `delay = mean + (z-score ? std)` where z-score is from normal distribution
  3. Accumulate all delays
  4. Result = base + sum of delays
- **Output**: 500 total travel times
- **P50 (Median)**: 50th percentile - represents typical travel time
- **P90 (90th Percentile)**: "Worst case" - 90% of simulations will be at or below this time

## Why Google Maps is Shorter

### Google Maps Advantages:
1. **Real-time traffic data**: Google has live traffic information from millions of users
2. **Historical pattern matching**: Uses machine learning on historical travel times for similar routes/times
3. **Current conditions**: Accounts for real-time incidents, road closures, transit delays
4. **Optimistic predictions**: Typically shows "best case" or slightly above average times

### This App's Conservative Approach:
1. **Uses scheduled times**: TfL API provides planned durations, not necessarily real-time
2. **Adds uncertainty margins**: P90 represents worst-case (90th percentile) - intentionally conservative
3. **Monte Carlo simulation**: Adds variability for every transit mode and transfer
4. **Disruption-aware**: Assumes delays will occur based on disruption severity
5. **Weather penalties**: Adds time for walking in rain conditions

### Example Scenario:
**Journey**: 10 min walk ? 15 min tube ? 5 min walk ? 20 min national rail

**Google Maps might show**: ~50 minutes (sum of legs)

**This app calculates**:
- Base: 10 + 15 + 5 + 20 = 50 min
- Weather penalty: 0 min (no rain)
- Baseline priors: 
  - Walk: no prior
  - Tube: std=1.0 min
  - Walk: no prior  
  - Rail: std=3.0 min
  - Transfer: std=1.0 min
- Monte Carlo (500 samples): 
  - P50 ? 51-52 min (median)
  - P90 ? 56-58 min (worst case)

**Result**: App shows 51 min (P50) vs Google's 50 min, with worst-case of 58 min (P90)

## Recommendations

### If you want more Google Maps-like predictions:
1. **Use P50 as primary**: Already doing this ?
2. **Reduce uncertainty priors**: Lower the std values in `baselinePriors()`
3. **Use real-time APIs**: Integrate live transit delays when available
4. **Adjust confidence thresholds**: P90 might be too conservative for some users

### If you want even more conservative predictions:
1. **Use P95 or P99**: Change percentile in `UncertaintyModel`
2. **Increase disruption priors**: More severe delays for disruptions
3. **Add more baseline variability**: Increase std values for transit modes

## Current Settings
- **Monte Carlo samples**: 500
- **Rain sensitivity (k)**: 0.08 (from UserPrefs)
- **Primary display**: P50 (median)
- **Worst case display**: P90 (90th percentile)
- **Confidence calculation**: `1.0 - (P90 - P50) / 50.0`