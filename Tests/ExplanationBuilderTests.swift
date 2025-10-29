import Foundation

func testRationaleIncludesChangesAndRain() {
    let text = ExplanationBuilder().rationale(p50: 30, p90: 32, changes: 1, rainDelta: 2, hasSevereDelaysOnKeyLeg: false, keyLineName: "District")
    assert(text.contains("1 change"))
    assert(text.contains("adds +2m walking"))
}
