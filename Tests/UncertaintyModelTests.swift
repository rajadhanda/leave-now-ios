import Foundation

func testConfidenceDropsWithHigherSpread() {
    let model = UncertaintyModel(draws: 500)
    let lowConf = model.confidence(p50: 20, p90: 30)
    let highConf = model.confidence(p50: 20, p90: 22)
    assert(highConf > lowConf)
}
