# Car Routing Setup Guide

## Overview
The app now supports car travel legs with live traffic data from HERE API. This provides:
- Real-time traffic-aware routing
- Road closure detection
- Traffic incident awareness
- Multiple route alternatives

## Setup Instructions

### 1. Get HERE API Key

1. Sign up for a HERE account at [https://developer.here.com/](https://developer.here.com/)
2. Create a new project in the HERE Developer Portal
3. Generate an API key for "Routing API" or "Freemium" tier
4. Copy your API key

### 2. Add API Key to Secrets.plist

1. Open `App/Support/Secrets.plist`
2. Add the following key-value pair:
   ```xml
   <key>HERE_API_KEY</key>
   <string>your-here-api-key-here</string>
   ```
3. If you don't have `Secrets.plist`, copy `Secrets.plist.example` and rename it

### 3. Features

#### Traffic-Aware Routing
- Uses HERE Routing API v8 with traffic mode enabled
- `departureTime` parameter ensures traffic predictions for the departure time
- Prefers `duration` (with traffic) over `baseDuration` (without traffic)

#### Uncertainty Modeling
- Car legs use dynamic uncertainty based on journey duration
- Formula: `stdMin = max(2.0, journeyMinutes * 0.10)`
- For a 30-minute drive: std = 3.0 minutes
- For a 60-minute drive: std = 6.0 minutes

#### Integration
- Car routes are automatically fetched alongside transit routes
- Best route is selected using the same scoring algorithm as transit
- App gracefully degrades if HERE API is unavailable (transit routes still work)

## API Limits (HERE Freemium Tier)

- **Free tier**: 250,000 requests/month
- **Rate limit**: Typically generous for personal use
- **Traffic data**: Included in freemium tier

## Alternative APIs

If you prefer a different provider, you can modify `HereMapsService.swift`:

### Google Maps Directions API
- Pros: More accurate, better coverage
- Cons: Requires billing account, higher cost

### Mapbox Directions API
- Pros: Good free tier, open-source friendly
- Cons: Requires credit card for higher limits

### Waze API
- Note: Waze doesn't provide a public routing API for developers
- The Waze Partner program is restricted to large partners

## Testing

To test car routing:
1. Ensure `HERE_API_KEY` is set in `Secrets.plist`
2. The app will automatically include car routes when calculating journey options
3. Check the route label: it should show "Car (X min)" for car routes
4. Compare with Google Maps predictions to validate accuracy

## Troubleshooting

### Car routes not appearing
- Check that `HERE_API_KEY` is set correctly
- Verify the API key is valid and has routing permissions
- Check console logs for HERE API errors

### Incorrect travel times
- HERE API traffic data may differ from Google Maps
- The app uses P50 (median) for display, which is more conservative
- Check P90 (worst case) to see the uncertainty range

### API errors
- Verify your HERE API key is active
- Check your account quota hasn't been exceeded
- Ensure network connectivity