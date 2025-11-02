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

    func recommend(plans: [JourneyPlan], weather: Weather?, disruptions: [Disruption], trafficInfoByPlan: [[TrafficInfo]] = []) -> RecommendationResult? {
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
        func baselinePriors(for plan: JourneyPlan, trafficInfo: [TrafficInfo] = []) -> [DelayPrior] {
            var priors: [DelayPrior] = []
            var trafficIndex = 0
            // Add small variability for each non-walk leg
            for leg in plan.legs where leg.mode != .walk {
                switch leg.mode {
                case .tube: priors.append(DelayPrior(meanMin: 0.0, stdMin: 1.0))
                case .bus: priors.append(DelayPrior(meanMin: 0.0, stdMin: 2.0))
                case .overground: priors.append(DelayPrior(meanMin: 0.0, stdMin: 1.5))
                case .dlr: priors.append(DelayPrior(meanMin: 0.0, stdMin: 1.0))
                case .nationalRail: priors.append(DelayPrior(meanMin: 0.0, stdMin: 3.0))
                case .car:
                    // Car legs have traffic-dependent variability
                    if trafficIndex < trafficInfo.count {
                        let traffic = trafficInfo[trafficIndex]
                        // Base variability increases with traffic level
                        let baseStdMin: Double = {
                            switch traffic.trafficLevel {
                            case .light: return 2.0      // Low variability in light traffic
                            case .moderate: return 4.0   // Moderate variability
                            case .heavy: return 6.0      // High variability
                            case .severe: return 8.0     // Very high variability
                            }
                        }()
                        // Add mean delay based on current traffic delay
                        let meanDelay = Double(traffic.trafficDelayMinutes) * 0.7 // Conservative estimate
                        // Increase std dev based on incidents/closures
                        let incidentMultiplier = traffic.hasIncidents ? 1.5 : 1.0
                        let closureMultiplier = traffic.roadClosures.isEmpty ? 1.0 : 1.8
                        priors.append(DelayPrior(
                            meanMin: meanDelay,
                            stdMin: baseStdMin * incidentMultiplier * closureMultiplier
                        ))
                    } else {
                        // No traffic data available - use conservative defaults
                        priors.append(DelayPrior(meanMin: 3.0, stdMin: 5.0))
                    }
                    trafficIndex += 1
                case .walk: break
                }
            }
            // Transfers add variability
            if plan.changes > 0 {
                priors.append(DelayPrior(meanMin: 0.0, stdMin: Double(plan.changes) * 1.0))
            }
            return priors
        }
        let scored: [(JourneyPlan, Int, Int, Double, Double)] = plans.enumerated().map { index, plan in
            let base = estimator.baseETA(minutesForLegs: plan.legs.map { $0.durationMinutes })
            let rainDelta = estimator.applyWeatherPenalty(walkMinutes: plan.walkMinutes, rainIntensity: weather?.precipitationMmPerHr, k: kRain)
            // Get traffic info for this plan if available
            let trafficInfo = index < trafficInfoByPlan.count ? trafficInfoByPlan[index] : []
            let allPriors = baselinePriors(for: plan, trafficInfo: trafficInfo) + priorsFor(disruptions: disruptions)
            let (p50, p90) = model.simulateETADistribution(baseMinutes: base + rainDelta,
                                                           priors: allPriors,
                                                           samples: samples)
            let conf = max(0.0, min(1.0, 1.0 - Double(p90 - p50) / 50.0))
            let util = score(p50: p50, p90: p90, changes: plan.changes, walkMinutes: plan.walkMinutes, comfortBonus: 0)
            return (plan, p50, p90, conf, util)
        }
        let sorted = scored.sorted { $0.4 < $1.4 }
        func toRec(_ tup: (JourneyPlan, Int, Int, Double, Double)) -> EngineRecommendation {
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
        }
        let best = toRec(sorted[0])
        let fallback = sorted.count > 1 ? toRec(sorted[1]) : nil
        return RecommendationResult(best: best, fallback: fallback)
    }
}
