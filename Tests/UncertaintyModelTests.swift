import XCTest

@testable import LeaveNow

final class UncertaintyModelTests: XCTestCase {
    func testMonteCarloProducesOrderedP50P90() {
        let mc = MonteCarloUncertainty()
        let (p50, p90) = mc.simulateETADistribution(baseMinutes: 30,
                                                    priors: [.init(meanMin: 5, stdMin: 2)],
                                                    samples: 1000)
        XCTAssertGreaterThanOrEqual(p90, p50)
    }
}
