import Foundation

/// A scored route ready for presentation. Carries the facts the UI and the
/// departure decision need (rain penalty, disruption state) so nothing has to
/// be recomputed downstream.
struct EngineRecommendation {
    let plan: JourneyPlan
    let p50Minutes: Int
    let p90Minutes: Int
    let confidence: Double
    let rationale: String
    let rainDeltaMinutes: Int
    let severeDisruption: Bool
    let disruptedLine: String?
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

    /// Utility is a *cost*: lower is better. p50 plus penalties for variance,
    /// changes and walking, minus a comfort bonus.
    func score(p50: Int, p90: Int, changes: Int, walkMinutes: Int, comfortBonus: Double) -> Double {
        let spread = Double(p90 - p50)
        return Double(p50) + alpha * spread + beta * Double(changes) + gamma * Double(walkMinutes) - delta * comfortBonus
    }

    func recommend(plans: [JourneyPlan],
                   weather: Weather?,
                   disruptions: [Disruption],
                   trafficInfoByPlan: [[TrafficInfo]] = []) -> RecommendationResult? {
        guard !plans.isEmpty else { return nil }
        let model = MonteCarloUncertainty()
        let estimator = DefaultETAEstimator()
        let samples = 500

        func priorsFor(disruptions: [Disruption]) -> [DelayPrior] {
            disruptions.map { d in
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
            // Small per-leg variability (zero-mean so P50 stays aligned with the
            // provider's point estimate; only the spread grows).
            for leg in plan.legs where leg.mode != .walk {
                switch leg.mode {
                case .tube: priors.append(DelayPrior(meanMin: 0.0, stdMin: 0.5))
                case .bus: priors.append(DelayPrior(meanMin: 0.0, stdMin: 1.5))
                case .overground: priors.append(DelayPrior(meanMin: 0.0, stdMin: 1.0))
                case .dlr: priors.append(DelayPrior(meanMin: 0.0, stdMin: 0.5))
                case .nationalRail: priors.append(DelayPrior(meanMin: 0.0, stdMin: 2.0))
                case .car:
                    // Car legs have traffic-dependent variability.
                    if trafficIndex < trafficInfo.count {
                        let traffic = trafficInfo[trafficIndex]
                        let baseStdMin: Double = {
                            switch traffic.trafficLevel {
                            case .light: return 2.0
                            case .moderate: return 4.0
                            case .heavy: return 6.0
                            case .severe: return 8.0
                            }
                        }()
                        let meanDelay = Double(traffic.trafficDelayMinutes) * 0.7 // conservative
                        let incidentMultiplier = traffic.hasIncidents ? 1.5 : 1.0
                        let closureMultiplier = traffic.roadClosures.isEmpty ? 1.0 : 1.8
                        priors.append(DelayPrior(
                            meanMin: meanDelay,
                            stdMin: baseStdMin * incidentMultiplier * closureMultiplier
                        ))
                    } else {
                        priors.append(DelayPrior(meanMin: 3.0, stdMin: 5.0))
                    }
                    trafficIndex += 1
                case .walk: break
                }
            }
            // Transfers add variability.
            if plan.changes > 0 {
                priors.append(DelayPrior(meanMin: 0.0, stdMin: Double(plan.changes) * 0.75))
            }
            return priors
        }

        let scored: [ScoredPlan] = plans.enumerated().map { index, plan in
            let base = estimator.baseETA(minutesForLegs: plan.legs.map { $0.durationMinutes })
            let rainDelta = estimator.applyWeatherPenalty(walkMinutes: plan.walkMinutes,
                                                          rainIntensity: weather?.precipitationMmPerHr,
                                                          k: kRain)
            let trafficInfo = index < trafficInfoByPlan.count ? trafficInfoByPlan[index] : []
            // Only disruptions on THIS route's lines affect its ETA — that is what
            // lets disruptions actually differentiate one route from another.
            let matched = matchedDisruptions(for: plan, disruptions: disruptions)
            let worst = worstDisruption(matched)
            let allPriors = baselinePriors(for: plan, trafficInfo: trafficInfo) + priorsFor(disruptions: matched)
            let (p50, p90) = model.simulateETADistribution(baseMinutes: base + rainDelta,
                                                           priors: allPriors,
                                                           samples: samples)
            let conf = max(0.0, min(1.0, 1.0 - Double(p90 - p50) / 50.0))
            let util = score(p50: p50, p90: p90, changes: plan.changes, walkMinutes: plan.walkMinutes, comfortBonus: 0)
            return ScoredPlan(plan: plan, p50: p50, p90: p90, confidence: conf, utility: util,
                              rainDelta: rainDelta,
                              severeDisruption: worst?.severity == .severe,
                              disruptedLine: worst?.lineId)
        }

        let sorted = scored.sorted { $0.utility < $1.utility }
        let best = makeRecommendation(sorted[0], isFastest: true)
        let fallback = sorted.count > 1 ? makeRecommendation(sorted[1], isFastest: false) : nil
        return RecommendationResult(best: best, fallback: fallback)
    }

    // MARK: - Helpers

    private struct ScoredPlan {
        let plan: JourneyPlan
        let p50: Int
        let p90: Int
        let confidence: Double
        let utility: Double
        let rainDelta: Int
        let severeDisruption: Bool
        let disruptedLine: String?
    }

    private func makeRecommendation(_ s: ScoredPlan, isFastest: Bool) -> EngineRecommendation {
        EngineRecommendation(
            plan: s.plan,
            p50Minutes: s.p50,
            p90Minutes: s.p90,
            confidence: s.confidence,
            rationale: ExplanationBuilder().rationale(
                p50: s.p50,
                p90: s.p90,
                changes: s.plan.changes,
                rainDelta: s.rainDelta,
                hasSevereDelaysOnKeyLeg: s.severeDisruption,
                keyLineName: s.disruptedLine,
                isFastest: isFastest),
            rainDeltaMinutes: s.rainDelta,
            severeDisruption: s.severeDisruption,
            disruptedLine: s.disruptedLine)
    }

    /// Disruptions whose line appears on the given route (tolerant id/name match).
    private func matchedDisruptions(for plan: JourneyPlan, disruptions: [Disruption]) -> [Disruption] {
        let planLines = plan.legs.compactMap { $0.lineId?.lowercased() }.filter { !$0.isEmpty }
        guard !planLines.isEmpty else { return [] }
        return disruptions.filter { d in
            let id = d.lineId.lowercased()
            return planLines.contains { $0 == id || $0.contains(id) || id.contains($0) }
        }
    }

    private func worstDisruption(_ disruptions: [Disruption]) -> Disruption? {
        disruptions.max { severityRank($0.severity) < severityRank($1.severity) }
    }

    private func severityRank(_ severity: DisruptionSeverity) -> Int {
        switch severity {
        case .minor: return 1
        case .moderate: return 2
        case .severe: return 3
        }
    }
}
