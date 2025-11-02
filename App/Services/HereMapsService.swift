import Foundation
import CoreLocation

/// Service for car routing with live traffic data using HERE API
struct HereMapsService {
    private let session: URLSession
    private let apiKey: String
    
    init(session: URLSession = .shared, apiKey: String? = nil) {
        self.session = session
        self.apiKey = apiKey ?? Secrets.hereApiKey
    }
    
    /// Get car route with live traffic data
    /// - Parameters:
    ///   - origin: Starting location
    ///   - destination: Ending location
    ///   - departure: Desired departure time (used for traffic prediction)
    /// - Returns: Journey plan with car leg, or nil if no route found
    func carRoute(from origin: CLLocationCoordinate2D, 
                  to destination: CLLocationCoordinate2D,
                  departure: Date) async throws -> JourneyPlan? {
        guard !apiKey.isEmpty else {
            throw URLError(.badURL) // API key missing
        }
        
        var comps = URLComponents(string: "https://router.hereapi.com/v8/routes")!
        var items: [URLQueryItem] = [
            .init(name: "transportMode", value: "car"),
            .init(name: "origin", value: "\(origin.latitude),\(origin.longitude)"),
            .init(name: "destination", value: "\(destination.latitude),\(destination.longitude)"),
            .init(name: "return", value: "summary"),
            .init(name: "departureTime", value: ISO8601DateFormatter().string(from: departure)),
            .init(name: "apiKey", value: apiKey)
        ]
        
        // Request traffic-aware routing with alternatives
        items.append(.init(name: "alternatives", value: "2")) // Get 2 alternative routes
        
        comps.queryItems = items
        
        guard let url = comps.url else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200..<300).contains(http.statusCode) else {
            // Log error for debugging
            if let errorData = try? JSONDecoder().decode([String: Any].self, from: data) {
                print("HERE API error: \(errorData)")
            }
            throw URLError(.badServerResponse)
        }
        
        let dto = try JSONDecoder.here.decode(HereRoutingDTO.self, from: data)
        return dto.toJourneyPlans().first // Return first route as primary
    }
    
    /// Get car route duration in minutes (simpler interface)
    func carDuration(from origin: CLLocationCoordinate2D,
                    to destination: CLLocationCoordinate2D,
                    departure: Date) async throws -> Int {
        guard let plan = try await carRoute(from: origin, to: destination, departure: departure) else {
            throw URLError(.badServerResponse)
        }
        return plan.totalDurationMinutes
    }
}

// MARK: - HERE API DTO

private struct HereRoutingDTO: Decodable {
    let routes: [RouteDTO]?
    
    struct RouteDTO: Decodable {
        let id: String?
        let sections: [SectionDTO]?
        let summary: SummaryDTO?
    }
    
    struct SectionDTO: Decodable {
        let id: String?
        let type: String? // "transport"
        let departure: DepartureDTO?
        let arrival: ArrivalDTO?
        let summary: SectionSummaryDTO?
    }
    
    struct DepartureDTO: Decodable {
        let time: String? // ISO 8601
        let place: PlaceDTO?
    }
    
    struct ArrivalDTO: Decodable {
        let time: String? // ISO 8601
        let place: PlaceDTO?
    }
    
    struct PlaceDTO: Decodable {
        let location: LocationDTO?
        let name: String?
    }
    
    struct LocationDTO: Decodable {
        let lat: Double?
        let lng: Double?
    }
    
    struct SummaryDTO: Decodable {
        let duration: Int? // in seconds
        let length: Int? // in meters
        let baseDuration: Int? // in seconds (without traffic)
        let flags: [String]?
    }
    
    struct SectionSummaryDTO: Decodable {
        let duration: Int? // in seconds
        let length: Int? // in meters
        let baseDuration: Int? // in seconds (without traffic)
    }
    
    func toJourneyPlans() -> [JourneyPlan] {
        guard let routes else { return [] }
        
        return routes.compactMap { route -> JourneyPlan? in
            // Use route summary if available, otherwise sum section summaries
            let durationSeconds: Int
            if let summary = route.summary {
                // Prefer duration (includes traffic) over baseDuration
                durationSeconds = summary.duration ?? summary.baseDuration ?? 0
            } else if let sections = route.sections, !sections.isEmpty {
                // Sum up sections
                durationSeconds = sections.compactMap { $0.summary?.duration ?? $0.summary?.baseDuration }
                    .reduce(0, +)
            } else {
                return nil
            }
            
            let durationMinutes = max(1, Int(round(Double(durationSeconds) / 60.0)))
            
            let leg = RouteLeg(
                mode: .car,
                lineId: nil,
                fromStation: route.sections?.first?.departure?.place?.name,
                toStation: route.sections?.last?.arrival?.place?.name,
                durationMinutes: durationMinutes
            )
            
            return JourneyPlan(legs: [leg])
        }
    }
}

private extension JSONDecoder {
    static var here: JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }
}