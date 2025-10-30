import XCTest

@testable import LeaveNow

final class RecommenderTests: XCTestCase {
    func testUtilityPenalisesVarianceAndChanges() {
        let r = DefaultRecommender()
        let w = UtilityWeights(alphaVariance: 0.7, betaChanges: 2.0, gammaWalking: 0.3, deltaComfort: 1.0)
        let a = r.scoreRoute(p50: 32, p90: 39, changes: 1, walkingMinutes: 10, comfortBonus: 0.0, w: w)
        let b = r.scoreRoute(p50: 32, p90: 50, changes: 2, walkingMinutes: 10, comfortBonus: 0.0, w: w)
        XCTAssertLessThan(a.utility, b.utility)
    }
}
