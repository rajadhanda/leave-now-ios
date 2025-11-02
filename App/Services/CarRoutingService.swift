import Foundation
import CoreLocation

/// Service that aggregates car routing options from HERE API
struct CarRoutingService {
    let hereService: HereMapsService
    
    init() {
        self.hereService = HereMapsService()
    }
    
    /// Get car journey plans from origin to destination
    /// Returns multiple route alternatives if available
    func carJourneyPlans(from origin: CLLocationCoordinate2D,
                         to destination: CLLocationCoordinate2D,
                         departure: Date) async -> [JourneyPlan] {
        do {
            // HERE API can return multiple routes when alternatives are requested
            guard let plan = try await hereService.carRoute(
                from: origin,
                to: destination,
                departure: departure
            ) else {
                return []
            }
            return [plan]
        } catch {
            // Log error but return empty array for graceful degradation
            // This allows the app to work even if HERE API is unavailable
            print("Car routing error: \(error)")
            return []
        }
    }
}