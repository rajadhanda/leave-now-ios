import Foundation

public protocol ETAEstimator {
    func baseETA(minutesForLegs: [Int]) -> Int
    func applyWeatherPenalty(walkMinutes: Int, rainIntensity: Double?, k: Double) -> Int
}

public struct DefaultETAEstimator: ETAEstimator {
    public init() {}
    public func baseETA(minutesForLegs: [Int]) -> Int { minutesForLegs.reduce(0, +) }
    /// Extra walking minutes caused by rain.
    ///
    /// `rainIntensity` is normalised 0–1 (OpenWeather mm/h ÷ 10, clamped), and
    /// `k` is the user's rain sensitivity (default 0.5). A square-root curve
    /// makes light rain register: on a 10-minute walk at k = 0.5, light rain
    /// (~1 mm/h → 0.1) adds ~+2m and heavy rain (~8 mm/h → 0.8) adds ~+4m —
    /// the calibration targets. The old linear mm/10 · 0.08 formula gave heavy
    /// rain barely +1m on the same walk.
    public func applyWeatherPenalty(walkMinutes: Int, rainIntensity: Double?, k: Double) -> Int {
        guard let r = rainIntensity, r > 0 else { return 0 }
        let intensity = max(0.0, min(r, 1.0))
        return Int(round(Double(walkMinutes) * k * intensity.squareRoot()))
    }
}
