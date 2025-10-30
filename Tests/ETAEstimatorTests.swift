import XCTest

@testable import LeaveNow

final class ETAEstimatorTests: XCTestCase {
    func testWeatherPenaltyScalesWithRain() {
        let e = DefaultETAEstimator()
        let noRain = e.applyWeatherPenalty(walkMinutes: 20, rainIntensity: nil, k: 0.1)
        let light = e.applyWeatherPenalty(walkMinutes: 20, rainIntensity: 0.3, k: 0.1)
        XCTAssertEqual(noRain, 0)
        XCTAssertGreaterThan(light, 0)
    }
}
