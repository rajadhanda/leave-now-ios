import XCTest

@testable import LeaveNow

final class TripHistoryTests: XCTestCase {
    private var fileURL: URL!

    override func setUpWithError() throws {
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("trip-history-tests-\(UUID().uuidString).json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func makePending(id: UUID = UUID(), departed: Date? = nil) -> PendingTrip {
        PendingTrip(id: id,
                    createdAt: Date(timeIntervalSince1970: 1_000_000),
                    recommendedDeparture: Date(timeIntervalSince1970: 1_000_300),
                    routeFingerprint: RouteFingerprint(lineSequence: ["northern", "jubilee"], stopIds: nil),
                    routeLabel: "Northern → Jubilee",
                    predictedP50Minutes: 32,
                    predictedP90Minutes: 39,
                    actualDeparture: departed)
    }

    private func makeOutcome(recommendationId: UUID) -> OutcomeEvent {
        OutcomeEvent(id: UUID(),
                     recommendationId: recommendationId,
                     startedAt: Date(timeIntervalSince1970: 1_000_360),
                     endedAt: Date(timeIntervalSince1970: 1_002_400),
                     actualDurationMinutes: 34,
                     followedRoute: true,
                     departureDeltaMinutes: 1,
                     userArrivalJudgement: .asExpected,
                     deviationIntent: nil)
    }

    func testSaveThenRecentOutcomesReturnsIt() throws {
        let store = JSONTripHistoryStore(fileURL: fileURL)
        let outcome = makeOutcome(recommendationId: UUID())
        try store.save(outcome: outcome)
        XCTAssertEqual(try store.recentOutcomes(limit: 10), [outcome])
    }

    func testPendingAndOutcomeSurviveRelaunch() throws {
        let trip = makePending()
        do {
            let store = JSONTripHistoryStore(fileURL: fileURL)
            try store.savePending(trip)
        }

        // A fresh instance from the same file simulates an app relaunch.
        let reloaded = JSONTripHistoryStore(fileURL: fileURL)
        XCTAssertEqual(try reloaded.pendingTrip(), trip)

        try reloaded.markDeparted(at: Date(timeIntervalSince1970: 1_000_360))
        let outcome = makeOutcome(recommendationId: trip.id)
        try reloaded.save(outcome: outcome)

        let afterRelaunch = JSONTripHistoryStore(fileURL: fileURL)
        // Completing the trip clears the pending slot and archives the
        // outcome joined to its prediction snapshot.
        XCTAssertNil(try afterRelaunch.pendingTrip())
        let records = try afterRelaunch.recentTrips(limit: 10)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.outcome, outcome)
        XCTAssertEqual(records.first?.trip?.id, trip.id)
        XCTAssertEqual(records.first?.trip?.predictedP50Minutes, 32)
        XCTAssertEqual(records.first?.trip?.actualDeparture, Date(timeIntervalSince1970: 1_000_360))
    }

    func testUnrelatedOutcomeLeavesPendingInPlace() throws {
        let store = JSONTripHistoryStore(fileURL: fileURL)
        let trip = makePending()
        try store.savePending(trip)
        try store.save(outcome: makeOutcome(recommendationId: UUID()))
        XCTAssertEqual(try store.pendingTrip(), trip)
        XCTAssertNil(try store.recentTrips(limit: 10).first?.trip)
    }

    func testCorruptFileMeansEmptyHistory() throws {
        try Data("not json".utf8).write(to: fileURL)
        let store = JSONTripHistoryStore(fileURL: fileURL)
        XCTAssertNil(try store.pendingTrip())
        XCTAssertEqual(try store.recentTrips(limit: 10), [])
    }

    // MARK: - Route-compliance button selection (charter one-tap feedback)

    func testMatchingFingerprintSelectsArrivalJudgementButtons() {
        let fp = RouteFingerprint(lineSequence: ["northern", "jubilee"], stopIds: nil)
        XCTAssertEqual(OutcomeFeedback.buttonSet(recommended: fp, actual: fp), .arrivalJudgement)
        // Unknown actual route counts as compliant.
        XCTAssertEqual(OutcomeFeedback.buttonSet(recommended: fp, actual: nil), .arrivalJudgement)
    }

    func testDivergentFingerprintSelectsDeviationButtons() {
        let recommended = RouteFingerprint(lineSequence: ["northern", "jubilee"], stopIds: nil)
        let actual = RouteFingerprint(lineSequence: ["victoria"], stopIds: nil)
        XCTAssertEqual(OutcomeFeedback.buttonSet(recommended: recommended, actual: actual), .deviationIntent)
    }
}
