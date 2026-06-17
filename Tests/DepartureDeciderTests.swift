import XCTest

@testable import LeaveNow

final class DepartureDeciderTests: XCTestCase {
    private let decider = DepartureDecider()

    func testNoTargetDefaultsToLeaveNow() {
        let d = decider.decide(now: Date(), arriveBy: nil, p90Minutes: 30, preferFallback: false)
        XCTAssertEqual(d.decision, .leaveNow)
    }

    func testPlentyOfTimeMeansWait() {
        let now = Date()
        let arriveBy = now.addingTimeInterval(120 * 60) // 2h out, only a 30m trip
        let d = decider.decide(now: now, arriveBy: arriveBy, p90Minutes: 30, preferFallback: false)
        XCTAssertEqual(d.decision, .wait)
    }

    func testWithinSoonWindowMeansLeaveInMinutes() {
        let now = Date()
        let arriveBy = now.addingTimeInterval((30 + 5) * 60) // 5 minutes of slack
        let d = decider.decide(now: now, arriveBy: arriveBy, p90Minutes: 30, preferFallback: false)
        XCTAssertEqual(d.decision, .leaveInMinutes)
    }

    func testTightTimingMeansLeaveNow() {
        let now = Date()
        let arriveBy = now.addingTimeInterval(30 * 60) // must leave right now
        let d = decider.decide(now: now, arriveBy: arriveBy, p90Minutes: 30, preferFallback: false)
        XCTAssertEqual(d.decision, .leaveNow)
        XCTAssertEqual(d.recommendedDeparture.timeIntervalSince(now), 0, accuracy: 1.0)
    }

    func testPreferFallbackOverridesTiming() {
        let now = Date()
        let arriveBy = now.addingTimeInterval(120 * 60)
        let d = decider.decide(now: now, arriveBy: arriveBy, p90Minutes: 30, preferFallback: true)
        XCTAssertEqual(d.decision, .takeFallback)
    }
}
