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
        let model = MonteCarloUncertainty()
        let estimator = DefaultETAEstimator()
        let samples = 500
        func priorsFor(disruptions: [Disruption]) -> [DelayPrior] {
            return disruptions.map { d in
                switch d.severity {
                case .minor: return DelayPrior(meanMin: 2, stdMin: 1)
                case .moderate: return DelayPrior(meanMin: 5, stdMin: 2)
                case .severe: return DelayPrior(meanMin: 10, stdMin: 5)
                }
            }
        }
        let scored: [(JourneyPlan, Int, Int, Double, Double)] = plans.map { plan in
            let base = estimator.baseETA(minutesForLegs: plan.legs.map { $0.durationMinutes })
            let rainDelta = estimator.applyWeatherPenalty(walkMinutes: plan.walkMinutes, rainIntensity: weather?.precipitationMmPerHr, k: kRain)
            let (p50, p90) = model.simulateETADistribution(baseMinutes: base + rainDelta,
                                                           priors: priorsFor(disruptions: disruptions),
                                                           samples: samples)
            let conf = max(0.0, min(1.0, 1.0 - Double(p90 - p50) / 30.0))
            let util = score(p50: p50, p90: p90, changes: plan.changes, walkMinutes: plan.walkMinutes, comfortBonus: 0)
            return (plan, p50, p90, conf, util)
        }
        let sorted = scored.sorted { $0.4 < $1.4 }
        func toRec(_ tup: (JourneyPlan, Int, Int, Double, Double)) -> EngineRecommendation {
<<<<<<< Updated upstream
            EngineRecommendation(plan: tup.0,
                                p50Minutes: tup.1,
                                p90Minutes: tup.2,
                                confidence: tup.3,
                                rationale: ExplanationBuilder().rationale(p50: tup.1,
                                                                          p90: tup.2,
                                                                          changes: tup.0.changes,
                                                                          rainDelta: 0,
                                                                          hasSevereDelaysOnKeyLeg: false,
                                                                          keyLineName: nil))
=======
            EngineRecommendation(plan: tup.0, p50Minutes: tup.1, p90Minutes: tup.2, confidence: tup.3, rationale: ExplanationBuilder().rationale(p50: tup.1, p90: tup.2, changes: tup.0.changes, rainDelta: 0, hasSevereDelaysOnKeyLeg: false, keyLineName: nil))
>>>>>>> Stashed changes
        }
        let best = toRec(sorted[0])
        let fallback = sorted.count > 1 ? toRec(sorted[1]) : nil
        return RecommendationResult(best: best, fallback: fallback)
    }
}
