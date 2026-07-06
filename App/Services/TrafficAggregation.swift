import Foundation

/// Helper service to fetch traffic data for car legs in journey plans
struct TrafficAggregation {
    let trafficService: TrafficService?
    
    init() {
        switch AppConfig.trafficProvider {
        case .here:
            if let apiKey = Secrets.hereApiKey {
                self.trafficService = HereTrafficService(apiKey: apiKey)
            } else {
                self.trafficService = nil
            }
        case .google:
            if let apiKey = Secrets.googleApiKey {
                self.trafficService = GoogleTrafficService(apiKey: apiKey)
            } else {
                self.trafficService = nil
            }
        case .none:
            self.trafficService = nil
        }
    }
    
    /// Fetch traffic information for all car legs in the given plans
    /// - Parameters:
    ///   - plans: Journey plans that may contain car legs
    ///   - origin: Origin location for car routes
    ///   - destination: Destination location for car routes
    ///   - departureTime: When the trip starts
    /// - Returns: Array of TrafficInfo arrays, one per plan, where each array contains TrafficInfo for each car leg in that plan
    func fetchTrafficForPlans(_ plans: [JourneyPlan], origin: GeoPoint, destination: GeoPoint, departureTime: Date) async -> [[TrafficInfo]] {
        guard let trafficService = trafficService else {
            // No traffic service configured - return empty arrays
            return Array(repeating: [], count: plans.count)
        }
        
        var results: [[TrafficInfo]] = []
        
        for plan in plans {
            var planTrafficInfo: [TrafficInfo] = []
            
            // Check if this plan has car legs
            let carLegs = plan.legs.filter { $0.mode == .car }
            
            if !carLegs.isEmpty {
                // For now, if there are car legs, fetch traffic for the entire route
                // In the future, we could fetch traffic for each individual car leg
                do {
                    let trafficInfo = try await trafficService.trafficInfo(
                        from: origin,
                        to: destination,
                        departureTime: departureTime
                    )
                    // Add one TrafficInfo per car leg (reuse the same info for simplicity)
                    // A more sophisticated implementation would fetch traffic for each leg separately
                    planTrafficInfo = Array(repeating: trafficInfo, count: carLegs.count)
                } catch {
                    // Graceful failure: no traffic info for this plan
                    planTrafficInfo = []
                }
            }
            
            results.append(planTrafficInfo)
        }
        
        return results
    }
}
