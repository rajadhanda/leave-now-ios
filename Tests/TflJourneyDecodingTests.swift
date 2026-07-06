import XCTest

@testable import LeaveNow

/// Exercises the real TfL journey decoder against a canned (trimmed)
/// `journeyresults` payload: the canonical line id must come from
/// `routeOptions[].lineIdentifier.id`, not the human route name.
final class TflJourneyDecodingTests: XCTestCase {
    private let journeyJSON = """
    {
      "journeys": [
        {
          "legs": [
            {
              "duration": 6,
              "mode": { "id": "walking", "name": "walking" },
              "departurePoint": { "commonName": "Home" },
              "arrivalPoint": { "commonName": "Moorgate Underground Station" },
              "routeOptions": [ { "name": "walk" } ]
            },
            {
              "duration": 14,
              "mode": { "id": "tube", "name": "tube" },
              "departurePoint": { "commonName": "Moorgate Underground Station" },
              "arrivalPoint": { "commonName": "Euston Underground Station" },
              "routeOptions": [
                {
                  "name": "Northern - via Bank",
                  "lineIdentifier": { "id": "northern", "name": "Northern" }
                }
              ]
            }
          ]
        }
      ]
    }
    """

    func testLineIdComesFromLineIdentifierNotRouteName() throws {
        let plans = try TflTransitService.plans(fromJourneyData: Data(journeyJSON.utf8))
        XCTAssertEqual(plans.count, 1)
        let tubeLeg = try XCTUnwrap(plans.first?.legs.first { $0.mode == .tube })
        XCTAssertEqual(tubeLeg.lineId, "northern")
        XCTAssertEqual(tubeLeg.lineName, "Northern")
        XCTAssertEqual(tubeLeg.fromStation, "Moorgate Underground Station")
        XCTAssertEqual(tubeLeg.durationMinutes, 14)

        // Walking legs carry no line: their routeOptions name is a street
        // directive, which must not leak into labels or matching.
        let walkLeg = try XCTUnwrap(plans.first?.legs.first { $0.mode == .walk })
        XCTAssertNil(walkLeg.lineId)
        XCTAssertNil(walkLeg.lineName)
    }

    func testDisruptionMatchesByCanonicalLineIdOnly() throws {
        let northern = JourneyPlan(legs: [
            RouteLeg(mode: .tube, lineId: "northern", lineName: "Northern",
                     fromStation: "Moorgate", toStation: "Euston", durationMinutes: 20)
        ])
        let victoria = JourneyPlan(legs: [
            RouteLeg(mode: .tube, lineId: "victoria", lineName: "Victoria",
                     fromStation: "Kings Cross", toStation: "Euston", durationMinutes: 20)
        ])
        let disruption = Disruption(lineId: "northern", affectedStations: [], severity: .severe)

        let rec = RecommenderV2(kRain: 0.5, alpha: 0.7, beta: 2.0, gamma: 0.3, delta: 1.0)
        let result = try XCTUnwrap(rec.recommend(plans: [northern, victoria],
                                                 weather: nil,
                                                 disruptions: [disruption]))

        // The undisrupted Victoria route must win, unaffected by the Northern
        // disruption; the Northern route carries it and a raised worst case.
        let best = result.best
        let fallback = try XCTUnwrap(result.fallback)
        XCTAssertEqual(best.plan.legs.first?.lineId, "victoria")
        XCTAssertFalse(best.severeDisruption)
        XCTAssertTrue(fallback.severeDisruption)
        XCTAssertEqual(fallback.disruptedLine, "northern")
        XCTAssertGreaterThan(fallback.p90Minutes, best.p90Minutes)
    }
}
