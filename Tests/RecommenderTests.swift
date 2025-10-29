import Foundation

func testPrefersLowerP50WhenSpreadSimilar() {
    let p1 = JourneyPlan(legs: [RouteLeg(mode: .tube, lineId: "dist", fromStation: nil, toStation: nil, durationMinutes: 20)])
    let p2 = JourneyPlan(legs: [RouteLeg(mode: .tube, lineId: "dist", fromStation: nil, toStation: nil, durationMinutes: 25)])
    let rec = RecommenderV2(kRain: 0.08, alpha: 0.7, beta: 2, gamma: 0.3, delta: 1.0).recommend(plans: [p1, p2], weather: nil, disruptions: [])
    assert(rec?.best.plan.totalDurationMinutes == 20)
}
