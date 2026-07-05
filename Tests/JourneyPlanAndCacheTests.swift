import XCTest

@testable import LeaveNow

final class JourneyPlanChangesTests: XCTestCase {
    private func leg(_ mode: LegMode, line: String?, minutes: Int = 10) -> RouteLeg {
        RouteLeg(mode: mode, lineId: line, fromStation: nil, toStation: nil, durationMinutes: minutes)
    }

    func testSameLineAdjacentTransitLegsAreNotAChange() {
        // e.g. TfL splitting a Northern-line journey at a via point.
        let plan = JourneyPlan(legs: [
            leg(.walk, line: nil),
            leg(.tube, line: "northern"),
            leg(.tube, line: "northern"),
            leg(.walk, line: nil)
        ])
        XCTAssertEqual(plan.changes, 0)
    }

    func testDifferentLinesCountAsChanges() {
        let plan = JourneyPlan(legs: [
            leg(.tube, line: "northern"),
            leg(.tube, line: "jubilee"),
            leg(.tube, line: "jubilee")
        ])
        XCTAssertEqual(plan.changes, 1)
    }

    func testUnknownLineIdsStillCountAsChanges() {
        // Two adjacent transit legs with no ids can't be proven to be the
        // same service, so the interchange is assumed.
        let plan = JourneyPlan(legs: [
            leg(.bus, line: nil),
            leg(.bus, line: nil)
        ])
        XCTAssertEqual(plan.changes, 1)
    }

    func testSingleTransitLegHasNoChanges() {
        let plan = JourneyPlan(legs: [leg(.walk, line: nil), leg(.tube, line: "victoria")])
        XCTAssertEqual(plan.changes, 0)
    }
}

@MainActor
final class RecommendationCacheTests: XCTestCase {
    /// A second refresh() within ttlSeconds must reuse the cached result and
    /// make no live fetch (which stands in for "no network call").
    func testSecondRefreshWithinTTLDoesNotRefetch() async {
        var fetchCount = 0
        let vm = RecommendationViewModel(
            history: InMemoryTripHistoryStore(),
            liveFetch: {
                fetchCount += 1
                return RecommendationViewModel.mockRecommendation() // ttlSeconds: 300
            }
        )

        await vm.refresh()
        await vm.refresh()

        XCTAssertEqual(fetchCount, 1)
        XCTAssertEqual(vm.source, .live)
        XCTAssertNotNil(vm.rec)
    }
}
