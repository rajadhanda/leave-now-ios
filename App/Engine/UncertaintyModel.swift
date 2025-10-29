import Foundation

struct NormalDelayPrior {
    let meanMinutes: Double
    let stdMinutes: Double
}

enum DisruptionPriorFactory {
    static func prior(for severity: DisruptionSeverity) -> NormalDelayPrior {
        switch severity {
        case .minor: return .init(meanMinutes: 2, stdMinutes: 1)
        case .moderate: return .init(meanMinutes: 5, stdMinutes: 3)
        case .severe: return .init(meanMinutes: 12, stdMinutes: 6)
        }
    }
}

struct UncertaintyModel {
    let draws: Int
    let rng: RandomNumberGeneratorWrapper

    init(draws: Int = 500, rng: RandomNumberGeneratorWrapper = .init()) {
        self.draws = max(500, draws)
        self.rng = rng
    }

    func simulateETA(plan: JourneyPlan, weather: Weather?, disruptions: [Disruption], kRain: Double) -> [Int] {
        let estimator = ETAEstimator(kRain: kRain)
        // Map disruptions by line id for quick lookup
        let lineToPriors: [String: NormalDelayPrior] = disruptions.reduce(into: [:]) { dict, d in
            dict[d.lineId] = DisruptionPriorFactory.prior(for: d.severity)
        }
        var samples: [Int] = []
        samples.reserveCapacity(draws)
        for _ in 0..<draws {
            var total = 0
            for leg in plan.legs {
                var legMinutes = leg.durationMinutes
                if leg.mode == .walk {
                    let rain = weather?.precipitationMmPerHr ?? 0.0
                    let delta = Int(round(Double(leg.durationMinutes) * kRain * rain))
                    legMinutes += max(0, delta)
                } else {
                    if let line = leg.lineId, let prior = lineToPriors[line] {
                        let sampled = Int(round(sampleNormal(mean: prior.meanMinutes, std: prior.stdMinutes)))
                        legMinutes += max(0, sampled)
                    }
                }
                total += legMinutes
            }
            samples.append(total)
        }
        return samples.sorted()
    }

    func pQuantiles(from sortedSamples: [Int]) -> (p50: Int, p90: Int) {
        guard !sortedSamples.isEmpty else { return (0, 0) }
        let n = sortedSamples.count
        let idx50 = min(n - 1, Int(Double(n - 1) * 0.50))
        let idx90 = min(n - 1, Int(Double(n - 1) * 0.90))
        return (sortedSamples[idx50], sortedSamples[idx90])
    }

    func confidence(p50: Int, p90: Int) -> Double {
        let denom = max(Double(p50), 1.0)
        let val = 1.0 - (Double(p90 - p50) / denom)
        return max(0.0, min(1.0, val))
    }

    private func sampleNormal(mean: Double, std: Double) -> Double {
        // Box-Muller
        var u1 = rng.nextUniform()
        var u2 = rng.nextUniform()
        while u1 <= .leastNonzeroMagnitude { u1 = rng.nextUniform() }
        let z0 = sqrt(-2.0 * log(u1)) * cos(2.0 * .pi * u2)
        return mean + std * z0
    }
}

final class RandomNumberGeneratorWrapper {
    private var generator = SystemRandomNumberGenerator()
    func nextUniform() -> Double { Double.random(in: 0..<1, using: &generator) }
}
