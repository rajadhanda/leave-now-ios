# Car Travel Support Implementation

## Overview

This document describes the implementation of car travel leg support with live traffic data integration.

## Changes Made

### 1. Added Car Mode to Enums

- **RouteLeg.swift**: Added `car` to `LegMode` enum
- **Recommendation.swift**: Added `car` to `LegType` enum

### 2. Traffic Service Implementation

Created `TrafficService.swift` with:

- **TrafficService Protocol**: Defines interface for fetching live traffic data
- **TrafficInfo**: Contains traffic information including:
  - Base duration (free-flow traffic)
  - Current duration (with live traffic)
  - Traffic delay minutes
  - Traffic level (light, moderate, heavy, severe)
  - Road closures
  - Incidents

- **HereTrafficService**: Implementation using HERE Routing API
  - Uses HERE Routing API v8 with real-time traffic
  - Fetches traffic-aware routing information
  - Detects incidents and road closures

- **GoogleTrafficService**: Alternative implementation using Google Directions API
  - Uses Google Directions API with `traffic_model=best_guess`
  - Fetches duration with live traffic
  - Detects warnings for closures/accidents

### 3. Updated RecommenderV2

- Modified `baselinePriors()` to accept `trafficInfo` parameter
- Added car leg handling with traffic-dependent variability:
  - **Light traffic**: stdMin = 2.0
  - **Moderate traffic**: stdMin = 4.0
  - **Heavy traffic**: stdMin = 6.0
  - **Severe traffic**: stdMin = 8.0
  - Applies multipliers for incidents (1.5x) and road closures (1.8x)
  - Uses current traffic delay as mean delay (conservatively at 70% of reported delay)

- Updated `recommend()` method to accept `trafficInfoByPlan` parameter
- Maps traffic info to car legs in each plan

### 4. Configuration Updates

- **Config.swift**:
  - Added `TrafficProvider` enum (here, google, none)
  - Added `TrafficSecrets` enum for API key access
  - Updated `AppConfig` to detect configured traffic provider

- **Secrets.plist.example**: Added placeholder keys:
  - `HERE_API_KEY`
  - `GOOGLE_MAPS_API_KEY`

### 5. Traffic Aggregation Service

Created `TrafficAggregation.swift`:
- Helper service that automatically selects traffic provider based on config
- Fetches traffic data for all car legs in journey plans
- Returns array of TrafficInfo arrays (one per plan)

### 6. Integration in LeaveNowView

- Added traffic data fetching step before recommendation
- Passes traffic info to RecommenderV2
- Updated `mapMode()` function to include car mode
- Updated leg mode switch statement to include car

## API Configuration

### HERE API

1. Sign up at https://developer.here.com/
2. Get an API key from the HERE Developer Portal
3. Add `HERE_API_KEY` to your `Secrets.plist` (or `Info.plist`)

### Google Maps Directions API

1. Create a project in Google Cloud Console
2. Enable "Directions API"
3. Create an API key with appropriate restrictions
4. Add `GOOGLE_MAPS_API_KEY` to your `Secrets.plist` (or `Info.plist`)

## Traffic Variability Model

Car legs use traffic-aware variability:

- **Without traffic data**: Defaults to meanDelay = 3.0 min, stdMin = 5.0 (conservative)
- **With traffic data**:
  - Mean delay = 70% of reported traffic delay (conservative estimate)
  - Std dev varies by traffic level and incident/closure presence
  - Incidents multiply std dev by 1.5x
  - Road closures multiply std dev by 1.8x

## Usage

1. Ensure you have either HERE or Google Maps API key configured
2. When creating journey plans with car legs, the system will:
   - Automatically detect car legs
   - Fetch live traffic data for those legs
   - Apply traffic-aware variability in ETA calculation
   - Include traffic delays in P50/P90 estimates

## Example

A journey plan with a car leg will:
1. Fetch traffic info for the car route
2. Get base duration (e.g., 25 minutes free-flow)
3. Get current duration (e.g., 35 minutes with traffic)
4. Calculate traffic delay (10 minutes)
5. Determine traffic level (e.g., "heavy")
6. Apply variability:
   - Mean delay = 7 minutes (70% of 10)
   - Std dev = 6.0 (heavy traffic)
   - If incident detected: std dev = 9.0 (6.0 ? 1.5)
7. Include in Monte Carlo simulation for P50/P90 calculation

## Future Enhancements

- Per-leg traffic fetching (currently fetches once per route)
- Real-time traffic updates during trip
- Alternative route suggestions based on traffic
- Integration with Waze API (if available)
- Parking time estimation for car legs
