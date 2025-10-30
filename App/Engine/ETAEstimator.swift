import Foundation

public protocol ETAEstimator {
    func baseETA(minutesForLegs: [Int]) -> Int
    func applyWeatherPenalty(walkMinutes: Int, rainIntensity: Double?, k: Double) -> Int
}

public struct DefaultETAEstimator: ETAEstimator {
    public init() {}
    public func baseETA(minutesForLegs: [Int]) -> Int { minutesForLegs.reduce(0, +) }
    public func applyWeatherPenalty(walkMinutes: Int, rainIntensity: Double?, k: Double) -> Int {
        guard let r = rainIntensity else { return 0 }
        return Int(round(Double(walkMinutes) * k * max(0.0, min(r, 1.0))))
    }
}
