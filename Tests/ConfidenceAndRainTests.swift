import XCTest

@testable import LeaveNow

final class ConfidenceAndRainTests: XCTestCase {
    /// The "stable variance" phrase, the score, and the level all derive from
    /// one spread function, so no spread may produce a contradictory pairing
    /// like "stable variance" + a non-high level.
    func testStableVarianceAlwaysImpliesHighLevel() {
        for spread in 0...60 where ConfidenceModel.isStable(spreadMinutes: spread) {
            XCTAssertEqual(ConfidenceModel.level(spreadMinutes: spread), .high,
                           "spread \(spread) is 'stable' but not high confidence")
        }
    }

    func testLevelAgreesWithScoreBuckets() {
        for spread in 0...60 {
            let score = ConfidenceModel.score(spreadMinutes: spread)
            let expected: ConfidenceLevel = score > 0.75 ? .high : (score > 0.5 ? .medium : .low)
            XCTAssertEqual(ConfidenceModel.level(spreadMinutes: spread), expected)
        }
    }

    /// Calibration targets documented in `DefaultETAEstimator`: on a 10-minute
    /// walk at the default sensitivity (0.5), light rain (~1 mm/h → intensity
    /// 0.1) adds ~+2m and heavy rain (~8 mm/h → 0.8) adds ~+4m.
    func testRainPenaltyMatchesCalibrationTargets() {
        let e = DefaultETAEstimator()
        let k = 0.5
        let light = e.applyWeatherPenalty(walkMinutes: 10, rainIntensity: 0.1, k: k)
        let heavy = e.applyWeatherPenalty(walkMinutes: 10, rainIntensity: 0.8, k: k)
        XCTAssertEqual(light, 2)
        XCTAssertEqual(heavy, 4)
        XCTAssertGreaterThan(heavy, light)
        XCTAssertEqual(e.applyWeatherPenalty(walkMinutes: 10, rainIntensity: nil, k: k), 0)
        XCTAssertEqual(e.applyWeatherPenalty(walkMinutes: 10, rainIntensity: 0, k: k), 0)
    }
}
