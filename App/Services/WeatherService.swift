import Foundation

public protocol WeatherService {
    func currentRainIntensity(at lat: Double, lon: Double) async throws -> Double? // 0–1
}
