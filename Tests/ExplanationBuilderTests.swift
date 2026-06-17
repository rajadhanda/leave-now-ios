import XCTest

@testable import LeaveNow

final class ExplanationBuilderTests: XCTestCase {
    private let builder = ExplanationBuilder()

    func testFastestRouteMentionsChangesRainAndNoDelays() {
        let text = builder.rationale(p50: 30, p90: 32, changes: 1, rainDelta: 2,
                                     hasSevereDelaysOnKeyLeg: false, keyLineName: nil, isFastest: true)
        XCTAssertTrue(text.contains("Fastest median"))
        XCTAssertTrue(text.contains("1 change"))
        XCTAssertTrue(text.contains("+2m walking"))
        XCTAssertTrue(text.contains("no active delays"))
    }

    func testFallbackIsNotLabelledFastestAndSurfacesSevereDelays() {
        let text = builder.rationale(p50: 40, p90: 60, changes: 2, rainDelta: 0,
                                     hasSevereDelaysOnKeyLeg: true, keyLineName: "Northern", isFastest: false)
        XCTAssertFalse(text.contains("Fastest median"))
        XCTAssertTrue(text.contains("2 changes"))
        XCTAssertTrue(text.contains("severe delays on Northern"))
    }
}
