import XCTest

@testable import LeaveNow

/// Tests the live scoring engine (`RecommenderV2`). The utility score is a cost:
/// lower is better, so a preferred route should score *less* than a worse one.
final class RecommenderTests: XCTestCase {
    private let rec = RecommenderV2(kRain: 0.08, alpha: 0.7, beta: 2.0, gamma: 0.3, delta: 1.0)

    func testUtilityPenalisesVariance() {
        let stable = rec.score(p50: 32, p90: 39, changes: 1, walkMinutes: 10, comfortBonus: 0)
        let volatile = rec.score(p50: 32, p90: 50, changes: 1, walkMinutes: 10, comfortBonus: 0)
        XCTAssertLessThan(stable, volatile)
    }

    func testUtilityPenalisesChanges() {
        let oneChange = rec.score(p50: 30, p90: 35, changes: 1, walkMinutes: 8, comfortBonus: 0)
        let twoChanges = rec.score(p50: 30, p90: 35, changes: 2, walkMinutes: 8, comfortBonus: 0)
        XCTAssertLessThan(oneChange, twoChanges)
    }

    func testRecommendPicksFasterRouteAsBest() {
        let fast = JourneyPlan(legs: [
            RouteLeg(mode: .tube, lineId: "victoria", fromStation: "", toStation: "", durationMinutes: 20)
        ])
        let slow = JourneyPlan(legs: [
            RouteLeg(mode: .tube, lineId: "circle", fromStation: "", toStation: "", durationMinutes: 40)
        ])
        let result = rec.recommend(plans: [slow, fast], weather: nil, disruptions: [])
        XCTAssertNotNil(result)
        XCTAssertLessThanOrEqual(result!.best.p50Minutes, result!.fallback?.p50Minutes ?? .max)
    }
}
