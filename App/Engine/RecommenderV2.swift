import Foundation

struct EngineRecommendation {
    let plan: JourneyPlan
    let p50Minutes: Int
    let p90Minutes: Int
    let confidence: Double
    let rationale: String
}

struct RecommendationResult {
    let best: EngineRecommendation
    let fallback: EngineRecommendation?
}

struct RecommenderV2 {
    let kRain: Double
    let alpha: Double
    let beta: Double
    let gamma: Double
    let delta: Double

    func score(p50: Int, p90: Int, changes: Int, walkMinutes: Int, comfortBonus: Double) -> Double {
        let spread = Double(p90 - p50)
        return Double(p50) + alpha * spread + beta * Double(changes) + gamma * Double(walkMinutes) - delta * comfortBonus
    }

    func recommend(plans: [JourneyPlan], weather: Weather?, disruptions: [Disruption]) -> RecommendationResult? {
        guard !plans.isEmpty else { return nil }
        let model = UncertaintyModel(draws: 500)
        let scored: [(JourneyPlan, Int, Int, Double, Double)] = plans.map { plan in
            let samples = model.simulateETA(plan: plan, weather: weather, disruptions: disruptions, kRain: kRain)
            let q = model.pQuantiles(from: samples)
            let conf = model.confidence(p50: q.p50, p90: q.p90)
            let util = score(p50: q.p50, p90: q.p90, changes: plan.changes, walkMinutes: plan.walkMinutes, comfortBonus: 0)
            return (plan, q.p50, q.p90, conf, util)
        }
        let sorted = scored.sorted { $0.4 < $1.4 }
        func toRec(_ tup: (JourneyPlan, Int, Int, Double, Double)) -> EngineRecommendation {
            EngineRecommendation(plan: tup.0, p50Minutes: tup.1, p90Minutes: tup.2, confidence: tup.3, rationale: ExplanationBuilder().rationale(p50: tup.1, p90: tup.2, changes: tup.0.changes, rainDelta: 0, hasSevereDelaysOnKeyLeg: false, keyLineName: nil))
        }
        let best = toRec(sorted[0])
        let fallback = sorted.count > 1 ? toRec(sorted[1]) : nil
        return RecommendationResult(best: best, fallback: fallback)
    }
}
