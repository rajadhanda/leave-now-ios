import Foundation

/// Traffic information for a car route
public struct TrafficInfo {
    public let baseDurationMinutes: Int
    public let currentDurationMinutes: Int      // With live traffic
    public let trafficDelayMinutes: Int         // Additional time due to traffic
    public let trafficLevel: TrafficLevel       // Light, Moderate, Heavy, Severe
    public let roadClosures: [RoadClosure]      // Any closures on the route
    public let hasIncidents: Bool               // Accidents, breakdowns, etc.
    
    public init(
        baseDurationMinutes: Int,
        currentDurationMinutes: Int,
        trafficDelayMinutes: Int,
        trafficLevel: TrafficLevel,
        roadClosures: [RoadClosure],
        hasIncidents: Bool
    ) {
        self.baseDurationMinutes = baseDurationMinutes
        self.currentDurationMinutes = currentDurationMinutes
        self.trafficDelayMinutes = trafficDelayMinutes
        self.trafficLevel = trafficLevel
        self.roadClosures = roadClosures
        self.hasIncidents = hasIncidents
    }
}

public enum TrafficLevel: String, Codable {
    case light       // Free-flowing traffic
    case moderate    // Some congestion
    case heavy       // Significant delays
    case severe      // Major delays, gridlock
}

public struct RoadClosure: Codable {
    public let description: String
    public let affectsRoute: Bool               // Does it affect this specific route
    public let estimatedDelayMinutes: Int
    
    public init(description: String, affectsRoute: Bool, estimatedDelayMinutes: Int) {
        self.description = description
        self.affectsRoute = affectsRoute
        self.estimatedDelayMinutes = estimatedDelayMinutes
    }
}

/// Service for fetching live traffic data for car routes
public protocol TrafficService {
    /// Get traffic information for a driving route
    /// - Parameters:
    ///   - from: Origin location
    ///   - to: Destination location
    ///   - departureTime: When the trip starts (nil = now)
    /// - Returns: Traffic information including live delays and road conditions
    func trafficInfo(from: GeoPoint, to: GeoPoint, departureTime: Date?) async throws -> TrafficInfo
}

/// HERE API implementation for traffic data
/// 
/// Uses HERE Routing API v8 with real-time traffic
/// Documentation: https://developer.here.com/documentation/routing-api/8.17.0/dev_guide/index.html
/// Free tier limits: ~5,000 requests/month
public struct HereTrafficService: TrafficService {
    private let apiKey: String
    private let baseURL = "https://router.hereapi.com/v8"
    
    // Rate limiting to respect free tier (max 5 requests per minute conservatively)
    private static var lastRequestTime: Date?
    private static let minRequestInterval: TimeInterval = 12.0 // 12 seconds = 5 requests per minute
    
    public init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    public func trafficInfo(from: GeoPoint, to: GeoPoint, departureTime: Date?) async throws -> TrafficInfo {
        // Rate limiting to stay within free tier limits
        if let lastRequest = HereTrafficService.lastRequestTime {
            let timeSinceLastRequest = Date().timeIntervalSince(lastRequest)
            if timeSinceLastRequest < HereTrafficService.minRequestInterval {
                let waitTime = HereTrafficService.minRequestInterval - timeSinceLastRequest
                try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            }
        }
        HereTrafficService.lastRequestTime = Date()
        
        var urlComponents = URLComponents(string: "\(baseURL)/routes")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "apikey", value: apiKey), // HERE API v8 uses 'apikey' parameter
            URLQueryItem(name: "origin", value: "\(from.lat),\(from.lon)"),
            URLQueryItem(name: "destination", value: "\(to.lat),\(to.lon)"),
            URLQueryItem(name: "transportMode", value: "car"),
            URLQueryItem(name: "return", value: "summary,actions"),
            URLQueryItem(name: "routingMode", value: "fast"), // Uses live traffic data
        ]
        
        // Add departure time if specified (for predictive routing)
        if let departureTime = departureTime {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            queryItems.append(URLQueryItem(name: "departureTime", value: formatter.string(from: departureTime)))
        }
        
        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else {
            throw TrafficServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw TrafficServiceError.httpError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        
        // Parse HERE API response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let routes = json["routes"] as? [[String: Any]],
              let firstRoute = routes.first,
              let sections = firstRoute["sections"] as? [[String: Any]],
              let firstSection = sections.first,
              let summary = firstSection["summary"] as? [String: Any] else {
            // Log response for debugging
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("HERE API response: \(json)")
            }
            throw TrafficServiceError.invalidResponse
        }
        
        // Extract duration (in seconds from HERE API)
        // HERE API returns duration in seconds
        let durationSeconds = (summary["duration"] as? Int) ?? (summary["duration"] as? Double).map { Int($0) } ?? 0
        let durationMinutes = Int(round(Double(durationSeconds) / 60.0))
        
        // Extract base duration (free-flow, no traffic) - if available
        // HERE API may provide baseDuration in summary or we calculate it from traffic
        let baseDurationSeconds: Int
        if let base = summary["baseDuration"] as? Int {
            baseDurationSeconds = base
        } else if let base = (summary["baseDuration"] as? Double).map({ Int($0) }) {
            baseDurationSeconds = base
        } else {
            // If baseDuration not available, estimate from traffic-aware duration
            // HERE API typically returns duration already including traffic
            // We'll use the duration as base and estimate delay from traffic pattern
            baseDurationSeconds = durationSeconds
        }
        let baseDurationMinutes = Int(round(Double(baseDurationSeconds) / 60.0))
        
        // Calculate traffic delay
        // HERE API with routingMode=fast returns duration with traffic
        // If baseDuration isn't available, estimate it from typical free-flow speed
        let estimatedBaseDurationMinutes: Int
        if baseDurationMinutes == durationMinutes && durationMinutes > 0 {
            // Base duration not provided, estimate from distance if available
            if let length = summary["length"] as? Int ?? (summary["length"] as? Double).map({ Int($0) }) {
                // Estimate free-flow duration: assume 50 km/h average for urban/mixed roads
                // Length is in meters, speed in km/h: time (hours) = (length/1000) / 50
                // Time (minutes) = ((length/1000) / 50) * 60 = (length/1000) * 60/50 = (length/1000) * 1.2
                // Simplified: length in km * 1.2 minutes per km ? length/1000 * 1.2
                let lengthKm = Double(length) / 1000.0
                let avgSpeedKmh = 50.0 // Conservative urban speed
                estimatedBaseDurationMinutes = max(1, Int(round(lengthKm / avgSpeedKmh * 60.0)))
            } else {
                // Fallback: assume 15% traffic delay as conservative estimate
                estimatedBaseDurationMinutes = max(1, Int(Double(durationMinutes) * 0.85))
            }
        } else {
            estimatedBaseDurationMinutes = baseDurationMinutes
        }
        
        let trafficDelayMinutes = max(0, durationMinutes - estimatedBaseDurationMinutes)
        
        // Determine traffic level based on delay
        let trafficLevel = determineTrafficLevel(delayMinutes: trafficDelayMinutes, durationMinutes: durationMinutes)
        
        // Extract incidents/events from actions
        var closures: [RoadClosure] = []
        var hasIncidents = false
        
        if let actions = firstSection["actions"] as? [[String: Any]] {
            for action in actions {
                if let actionType = action["action"] as? String,
                   actionType == "incident" || actionType == "closure" {
                    hasIncidents = true
                    if let description = action["instruction"] as? String {
                        closures.append(RoadClosure(
                            description: description,
                            affectsRoute: true,
                            estimatedDelayMinutes: trafficDelayMinutes
                        ))
                    }
                }
            }
        }
        
        return TrafficInfo(
            baseDurationMinutes: estimatedBaseDurationMinutes,
            currentDurationMinutes: durationMinutes,
            trafficDelayMinutes: trafficDelayMinutes,
            trafficLevel: trafficLevel,
            roadClosures: closures,
            hasIncidents: hasIncidents
        )
    }
    
    private func determineTrafficLevel(delayMinutes: Int, durationMinutes: Int) -> TrafficLevel {
        guard durationMinutes > 0 else { return .light }
        let delayPercentage = Double(delayMinutes) / Double(durationMinutes)
        
        if delayPercentage > 0.5 {
            return .severe
        } else if delayPercentage > 0.3 {
            return .heavy
        } else if delayPercentage > 0.1 {
            return .moderate
        } else {
            return .light
        }
    }
}

public enum TrafficServiceError: Error {
    case invalidURL
    case httpError(statusCode: Int)
    case invalidResponse
    case apiKeyMissing
}

/// Google Maps Directions API implementation (alternative)
/// 
/// Uses Google Directions API with traffic_model parameter
/// Documentation: https://developers.google.com/maps/documentation/directions
public struct GoogleTrafficService: TrafficService {
    private let apiKey: String
    private let baseURL = "https://maps.googleapis.com/maps/api/directions/json"
    
    public init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    public func trafficInfo(from: GeoPoint, to: GeoPoint, departureTime: Date?) async throws -> TrafficInfo {
        var urlComponents = URLComponents(string: baseURL)!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "origin", value: "\(from.lat),\(from.lon)"),
            URLQueryItem(name: "destination", value: "\(to.lat),\(to.lon)"),
            URLQueryItem(name: "mode", value: "driving"),
            URLQueryItem(name: "departure_time", value: departureTime != nil ? "\(Int(departureTime!.timeIntervalSince1970))" : "now"),
            URLQueryItem(name: "traffic_model", value: "best_guess"), // Uses live traffic
        ]
        
        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else {
            throw TrafficServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw TrafficServiceError.httpError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        
        // Parse Google Maps response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              json["status"] as? String == "OK",
              let routes = json["routes"] as? [[String: Any]],
              let firstRoute = routes.first,
              let legs = firstRoute["legs"] as? [[String: Any]],
              let firstLeg = legs.first else {
            throw TrafficServiceError.invalidResponse
        }
        
        // Extract duration (with traffic) and duration_in_traffic
        let durationSeconds = (firstLeg["duration"] as? [String: Any])?["value"] as? Int ?? 0
        let durationMinutes = Int(round(Double(durationSeconds) / 60.0))
        
        let durationInTrafficSeconds = (firstLeg["duration_in_traffic"] as? [String: Any])?["value"] as? Int ?? durationSeconds
        let durationInTrafficMinutes = Int(round(Double(durationInTrafficSeconds) / 60.0))
        
        let baseDurationMinutes = durationMinutes // Base duration without traffic
        let trafficDelayMinutes = max(0, durationInTrafficMinutes - baseDurationMinutes)
        
        // Determine traffic level
        let trafficLevel = determineTrafficLevel(delayMinutes: trafficDelayMinutes, durationMinutes: durationInTrafficMinutes)
        
        // Check for incidents/road closures (available in Google Maps API)
        var closures: [RoadClosure] = []
        var hasIncidents = false
        
        // Google Maps provides warnings/waypoints for closures
        if let warnings = firstRoute["warnings"] as? [String], !warnings.isEmpty {
            hasIncidents = true
            for warning in warnings {
                if warning.lowercased().contains("closure") || warning.lowercased().contains("accident") {
                    closures.append(RoadClosure(
                        description: warning,
                        affectsRoute: true,
                        estimatedDelayMinutes: trafficDelayMinutes
                    ))
                }
            }
        }
        
        return TrafficInfo(
            baseDurationMinutes: baseDurationMinutes,
            currentDurationMinutes: durationInTrafficMinutes,
            trafficDelayMinutes: trafficDelayMinutes,
            trafficLevel: trafficLevel,
            roadClosures: closures,
            hasIncidents: hasIncidents
        )
    }
    
    private func determineTrafficLevel(delayMinutes: Int, durationMinutes: Int) -> TrafficLevel {
        guard durationMinutes > 0 else { return .light }
        let delayPercentage = Double(delayMinutes) / Double(durationMinutes)
        
        if delayPercentage > 0.5 {
            return .severe
        } else if delayPercentage > 0.3 {
            return .heavy
        } else if delayPercentage > 0.1 {
            return .moderate
        } else {
            return .light
        }
    }
}
