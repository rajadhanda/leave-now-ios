import Foundation

func testRainPenaltyAddsAtLeastOneMinuteOnTwentyMinWalk() {
    let est = ETAEstimator(kRain: 0.08)
    let delta = est.adjustedWalkMinutes(walkMinutes: 20, rainIntensity: 1.0) - 20
    assert(delta >= 1, "Expected at least 1 minute delta, got \(delta)")
}
