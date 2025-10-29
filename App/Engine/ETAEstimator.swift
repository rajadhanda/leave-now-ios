import Foundation

struct ETAEstimator {
    let kRain: Double // default around 0.08

    func adjustedWalkMinutes(walkMinutes: Int, rainIntensity: Double) -> Int {
        let delta = Double(walkMinutes) * kRain * rainIntensity
        return walkMinutes + Int(round(delta))
    }

    func estimate(plan: JourneyPlan, weather: Weather?) -> Int {
        let base = plan.totalDurationMinutes
        guard let weather = weather else { return base }
        let walkBase = plan.walkMinutes
        let walkAdjusted = adjustedWalkMinutes(walkMinutes: walkBase, rainIntensity: weather.precipitationMmPerHr)
        let nonWalk = base - walkBase
        return nonWalk + walkAdjusted
    }
}
