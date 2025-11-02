# HERE API Integration Guide

## Overview

The app now supports live traffic data for car travel legs using the HERE Routing API v8. This provides real-time traffic information, road closures, and incidents to improve ETA accuracy.

## API Configuration

### API Key

The HERE API key has been configured:
- **API Key**: `ojzOwOIBAC1mYSvuCD-1tnafFdilHf1bNsfk75m_dXM`
- **OAuth2.0 Credentials** (for reference, if needed in future):
  - Access Key ID: `bDiVPHI4SiADZ1HwgWMkyQ`
  - Access Key Secret: `bUVCCA3B3gBJ48n44Oaa6ebvARs6OWKAxt75kUD_J0MXZKQixeqxXgBgNtO4ETXvrSwrz7ZaGxzheM8oWRuw0g`

### Configuration Location

The API key is configured in:
- **Secrets.plist.example**: Contains the API key for reference
- **Runtime**: The app reads `HERE_API_KEY` from `Info.plist` or `Secrets.plist`
- **Config.swift**: `TrafficSecrets.hereApiKey` accesses the key

### Free Tier Limits

HERE API free tier typically includes:
- **Monthly requests**: ~5,000 requests/month
- **Rate limiting**: The implementation includes conservative rate limiting:
  - Minimum 12 seconds between requests (5 requests per minute)
  - Prevents exceeding free tier limits
  - Ensures sustainable API usage

## Implementation Details

### Traffic Service (`TrafficService.swift`)

The `HereTrafficService` implementation:

1. **Endpoint**: `https://router.hereapi.com/v8/routes`
2. **Authentication**: Uses `apikey` query parameter
3. **Request Parameters**:
   - `origin`: Latitude, longitude of origin
   - `destination`: Latitude, longitude of destination
   - `transportMode`: `car`
   - `routingMode`: `fast` (uses live traffic)
   - `return`: `summary,actions` (returns route summary and actions)
   - `departureTime`: ISO8601 formatted time (optional, for predictive routing)

4. **Rate Limiting**:
   - Implements 12-second minimum interval between requests
   - Prevents API quota exhaustion
   - Uses static tracking to enforce limits

5. **Response Parsing**:
   - Extracts duration (in seconds) from route summary
   - Attempts to extract `baseDuration` if available
   - If `baseDuration` not available, estimates from route length and typical speeds
   - Determines traffic level (light, moderate, heavy, severe)
   - Extracts incidents and road closures from actions

### Traffic Information Structure

`TrafficInfo` contains:
- **baseDurationMinutes**: Estimated free-flow travel time
- **currentDurationMinutes**: Actual travel time with live traffic
- **trafficDelayMinutes**: Additional time due to traffic
- **trafficLevel**: Classification of traffic severity
- **roadClosures**: List of road closures affecting route
- **hasIncidents**: Boolean indicating accidents/incidents

### Integration Flow

1. **Journey Plans**: App fetches journey plans (may include car legs)
2. **Traffic Aggregation**: `TrafficAggregation` service detects car legs
3. **API Calls**: For each plan with car legs, fetches traffic data
4. **Rate Limiting**: Ensures requests stay within free tier limits
5. **ETA Calculation**: Traffic delays integrated into Monte Carlo simulation
6. **Variability Adjustment**: Traffic level determines variability (std dev):
   - Light: 2.0 min
   - Moderate: 4.0 min
   - Heavy: 6.0 min
   - Severe: 8.0 min
   - Incidents: +50% multiplier
   - Road closures: +80% multiplier

## Usage Example

```swift
// The service is automatically initialized based on API key availability
let trafficAggregation = TrafficAggregation()

// Fetch traffic for journey plans with car legs
let trafficInfo = await trafficAggregation.fetchTrafficForPlans(
    plans,
    origin: GeoPoint(lat: 51.5074, lon: -0.1278),
    destination: GeoPoint(lat: 51.4816, lon: -0.0481),
    departureTime: Date()
)

// Traffic info is automatically used in ETA calculation
let result = recV2.recommend(
    plans: plans,
    weather: weather,
    disruptions: disruptions,
    trafficInfoByPlan: trafficInfo
)
```

## Error Handling

The implementation includes graceful error handling:
- Missing API key: Service returns empty traffic info arrays
- API errors: Logs response for debugging, continues without traffic data
- Rate limit exceeded: Service waits before retrying (within 12-second window)
- Invalid responses: Returns empty traffic info, doesn't crash app

## Future Enhancements

1. **Per-Leg Traffic**: Fetch traffic data for each individual car leg separately
2. **Real-Time Updates**: Refresh traffic data during active trips
3. **Alternative Routes**: Use traffic data to suggest faster routes
4. **OAuth2.0 Support**: Add OAuth2.0 authentication if needed for enterprise features
5. **Caching**: Cache traffic data for common routes to reduce API calls

## API Documentation

Full HERE API documentation:
- **Routing API v8**: https://developer.here.com/documentation/routing-api/8.17.0/dev_guide/index.html
- **Developer Portal**: https://developer.here.com/
- **API Explorer**: https://developer.here.com/api-explorer

## Security Notes

?? **Important**: The API key is included in `Secrets.plist.example` for convenience during development. For production:
1. Store API keys securely (not in version control)
2. Use environment variables or secure key management
3. Consider using OAuth2.0 for enhanced security
4. Monitor API usage to prevent abuse
