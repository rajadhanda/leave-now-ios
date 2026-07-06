import XCTest

@testable import LeaveNow

/// Exercises the production next-gen `/rtt/location` decoder
/// (`RealtimeTrainsService.railLegMetas`) against a canned line-up fixture —
/// not a locally redefined copy of the DTOs.
final class RealtimeTrainsDecodingTests: XCTestCase {
    private let lineUpJSON = """
    {
      "systemStatus": "ok",
      "query": { "code": "WAT", "filterTo": "RMD" },
      "services": [
        {
          "temporalData": {
            "departure": {
              "scheduleAdvertised": "2026-07-05T08:32:00+01:00",
              "realtimeForecast": "2026-07-05T08:34:00+01:00",
              "realtimeAdvertisedLateness": 2
            },
            "arrival": {
              "scheduleAdvertised": "2026-07-05T08:30:00+01:00"
            }
          },
          "locationMetadata": {
            "platform": { "planned": "4", "actual": "5" }
          },
          "scheduleMetadata": {
            "uniqueIdentity": "gb-nr:L01525:2026-07-05",
            "identity": "L01525",
            "departureDate": "2026-07-05",
            "operator": { "code": "SW", "name": "South Western Railway" }
          },
          "origin": [
            {
              "location": { "description": "London Waterloo", "shortCodes": ["WAT"] },
              "temporalData": { "scheduleAdvertised": "2026-07-05T08:32:00+01:00" }
            }
          ],
          "destination": [
            {
              "location": { "description": "Richmond", "shortCodes": ["RMD"] },
              "temporalData": {
                "scheduleAdvertised": "2026-07-05T08:49:00+01:00",
                "realtimeForecast": "2026-07-05T08:51:00+01:00"
              }
            }
          ]
        },
        {
          "temporalData": {
            "departure": { "scheduleAdvertised": "2026-07-05T08:40:00+01:00" }
          },
          "scheduleMetadata": { "uniqueIdentity": "gb-nr:L09999:2026-07-05" },
          "destination": [
            {
              "location": { "description": "Windsor & Eton Riverside", "shortCodes": ["WNR"] },
              "temporalData": { "scheduleAdvertised": "2026-07-05T09:20:00+01:00" }
            }
          ]
        }
      ]
    }
    """

    func testDecodesLineUpIntoRailLegMeta() throws {
        let metas = try RealtimeTrainsService.railLegMetas(from: Data(lineUpJSON.utf8),
                                                           originCRS: "WAT",
                                                           destCRS: "RMD",
                                                           limit: 5)
        // The second service's final destination (WNR) doesn't match filterTo,
        // so v1 skips it rather than reporting a wrong arrival.
        XCTAssertEqual(metas.count, 1)
        let meta = try XCTUnwrap(metas.first)

        XCTAssertEqual(meta.operatorName, "South Western Railway")
        XCTAssertEqual(meta.serviceId, "gb-nr:L01525:2026-07-05")
        XCTAssertEqual(meta.origin.crs, "WAT")
        XCTAssertEqual(meta.origin.name, "London Waterloo")
        XCTAssertEqual(meta.destination.crs, "RMD")
        XCTAssertEqual(meta.destination.name, "Richmond")
        XCTAssertEqual(meta.departure.platform, "5") // actual wins over planned

        // ISO-8601 offsets must be honoured: 08:32+01:00 == 07:32Z.
        XCTAssertEqual(meta.departure.plannedTime, Date(timeIntervalSince1970: 1_783_236_720))
        XCTAssertEqual(meta.departure.estimatedTime, Date(timeIntervalSince1970: 1_783_236_840))
        XCTAssertEqual(meta.arrival.plannedTime, Date(timeIntervalSince1970: 1_783_237_740))
        XCTAssertEqual(meta.arrival.estimatedTime, Date(timeIntervalSince1970: 1_783_237_860))
    }

    func testInitFailsWithoutToken() {
        XCTAssertNil(RealtimeTrainsService(baseURL: URL(string: "https://data.rtt.io"), token: nil))
        XCTAssertNil(RealtimeTrainsService(baseURL: URL(string: "https://data.rtt.io"), token: ""))
        XCTAssertNil(RealtimeTrainsService(baseURL: nil, token: "tok"))
        XCTAssertNotNil(RealtimeTrainsService(baseURL: URL(string: "https://data.rtt.io"), token: "tok"))
    }
}
