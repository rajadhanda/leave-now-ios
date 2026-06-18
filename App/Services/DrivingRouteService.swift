import Foundation
import CoreLocation

/// Produces a car-based `JourneyPlan` so driving is always offered as a candidate
/// alongside public-transport options. TfL only knows about London transit and
/// never returns car legs, so without this a "drive" leg can never appear.
///
/// The duration here is a free-flow (no-traffic) estimate. Live traffic delay is
/// layered on top by the existing traffic pipeline (`TrafficAggregation` →
/// `RecommenderV2`) when a provider is configured, so we avoid double-counting
/// congestion and avoid an extra rate-limited round-trip on every refresh.
struct DrivingRouteService {

    /// A single-leg driving plan, or `nil` when origin and destination are
    /// effectively the same point.
    func drivingPlan(from origin: CLLocationCoordinate2D, to dest: CLLocationCoordinate2D) -> JourneyPlan? {
        let minutes = Self.estimateDrivingMinutes(from: origin, to: dest)
        guard minutes > 0 else { return nil }
        let leg = RouteLeg(mode: .car, lineId: nil, fromStation: nil, toStation: nil, durationMinutes: minutes)
        return JourneyPlan(legs: [leg])
    }

    /// Rough free-flow driving time: great-circle distance inflated by a road
    /// circuity factor, at a distance-dependent average speed (urban vs. motorway).
    static func estimateDrivingMinutes(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Int {
        let straightLineKm = haversineKm(from, to)
        guard straightLineKm > 0.1 else { return 0 }
        let roadKm = straightLineKm * 1.3                       // typical road circuity
        let avgSpeedKmh = straightLineKm > 30 ? 80.0 : 35.0     // longer trips skew motorway
        let minutes = roadKm / avgSpeedKmh * 60.0
        return max(1, Int(minutes.rounded()))
    }

    private static func haversineKm(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let earthRadiusKm = 6371.0
        let dLat = (b.latitude - a.latitude) * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2)
            + sin(dLon / 2) * sin(dLon / 2) * cos(lat1) * cos(lat2)
        return 2 * earthRadiusKm * asin(min(1, sqrt(h)))
    }
}
