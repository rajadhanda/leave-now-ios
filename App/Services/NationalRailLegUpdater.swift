import Foundation

/// Updates National Rail legs in journey plans with real-time data from RealtimeTrains
/// Only processes National Rail legs; all other leg types (tube, bus, etc.) remain unchanged
struct NationalRailLegUpdater {
    /// Updates National Rail leg durations using RealtimeTrains data
    /// - Parameters:
    ///   - plans: Journey plans from TfL API
    ///   - railService: RealtimeTrains service for fetching real-time train data
    ///   - departureTime: Planned departure time for the journey
    /// - Returns: Updated journey plans with National Rail legs using RealtimeTrains durations
    static func updateNationalRailLegs(
        plans: [JourneyPlan],
        railService: RealtimeTrainsService?,
        departureTime: Date
    ) async -> [JourneyPlan] {
        guard let railService = railService else {
            // If RealtimeTrains service unavailable, return plans unchanged
            return plans
        }
        
        var updatedPlans: [JourneyPlan] = []
        
        for plan in plans {
            var updatedLegs: [RouteLeg] = []
            
            for leg in plan.legs {
                // Only update National Rail legs; leave all others unchanged
                guard leg.mode == .nationalRail else {
                    updatedLegs.append(leg)
                    continue
                }
                
                // Extract station names
                guard let fromStation = leg.fromStation,
                      let toStation = leg.toStation,
                      !fromStation.isEmpty,
                      !toStation.isEmpty else {
                    // Missing station names - keep original leg from TfL
                    updatedLegs.append(leg)
                    continue
                }
                
                // Map station names to CRS codes
                guard let fromCRS = StationNameMapper.crsCode(for: fromStation),
                      let toCRS = StationNameMapper.crsCode(for: toStation) else {
                    // CRS mapping failed - keep original leg from TfL
                    print("Warning: Could not map stations to CRS codes - \(fromStation) or \(toStation)")
                    updatedLegs.append(leg)
                    continue
                }
                
                // Fetch RealtimeTrains service data
                do {
                    let services = try await railService.nextServices(
                        from: fromCRS,
                        to: toCRS,
                        around: departureTime,
                        limit: 1
                    )
                    
                    guard let service = services.first else {
                        // No services found - keep original leg from TfL
                        updatedLegs.append(leg)
                        continue
                    }
                    
                    // Calculate duration from RealtimeTrains data
                    // Use estimated times if available, otherwise use planned times
                    let departureTime = service.departure.estimatedTime ?? service.departure.plannedTime
                    let arrivalTime = service.arrival.estimatedTime ?? service.arrival.plannedTime
                    
                    let durationSeconds = arrivalTime.timeIntervalSince(departureTime)
                    let durationMinutes = max(1, Int(round(durationSeconds / 60.0)))
                    
                    // Create updated leg with RealtimeTrains duration
                    let updatedLeg = RouteLeg(
                        mode: leg.mode,
                        lineId: leg.lineId,
                        lineName: leg.lineName,
                        fromStation: leg.fromStation,
                        toStation: leg.toStation,
                        durationMinutes: durationMinutes
                    )
                    
                    updatedLegs.append(updatedLeg)
                    
                } catch {
                    // RealtimeTrains lookup failed - keep original leg from TfL
                    print("Warning: RealtimeTrains lookup failed for \(fromCRS)→\(toCRS): \(error.localizedDescription)")
                    updatedLegs.append(leg)
                }
            }
            
            // Create updated journey plan with modified legs
            let updatedPlan = JourneyPlan(legs: updatedLegs)
            updatedPlans.append(updatedPlan)
        }
        
        return updatedPlans
    }
}

