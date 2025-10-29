import Foundation

struct DeterministicRecommendation {
    let plan: JourneyPlan
    let p50: Int
    let p90: Int
    let confidence: Double
    let rationale: String
}

struct RecommenderV1 {
    let etaEstimator: ETAEstimator

    func recommend(plans: [JourneyPlan], weather: Weather?) -> DeterministicRecommendation? {
        guard !plans.isEmpty else { return nil }
        let scored = plans.map { plan -> (JourneyPlan, Int) in
            (plan, etaEstimator.estimate(plan: plan, weather: weather))
        }
        let best = scored.min { $0.1 < $1.1 }!
        let p50 = best.1
        let p90 = best.1 // v1 deterministic; will expand in v2
        let confidence = 1.0 // v1 deterministic placeholder
        let rationale = ExplanationBuilder().rationale(p50: p50, p90: p90, changes: best.0.changes, rainDelta: best.0.walkMinutes == 0 ? 0 : 0, hasSevereDelaysOnKeyLeg: false, keyLineName: nil)
        return DeterministicRecommendation(plan: best.0, p50: p50, p90: p90, confidence: confidence, rationale: rationale)
    }
}
