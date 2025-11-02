import Foundation

public struct DelayPrior {
    public enum Severity { case minor, moderate, severe }
    public let meanMin: Double
    public let stdMin: Double
    public init(meanMin: Double, stdMin: Double) { self.meanMin = meanMin; self.stdMin = stdMin }
}

public protocol UncertaintyModel {
    func simulateETADistribution(baseMinutes: Int, priors: [DelayPrior], samples: Int) -> (p50: Int, p90: Int)
}

public struct MonteCarloUncertainty: UncertaintyModel {
    public init() {}
    public func simulateETADistribution(baseMinutes: Int, priors: [DelayPrior], samples: Int) -> (p50: Int, p90: Int) {
        var totals: [Double] = []
        totals.reserveCapacity(samples)
        for _ in 0..<samples {
            var delay: Double = 0
            for p in priors {
                // Box-Muller normal sample
                let u1 = Double.random(in: 0..<1), u2 = Double.random(in: 0..<1)
                let z0 = sqrt(-2.0 * log(u1)) * cos(2 * .pi * u2)
                // Don't clamp intermediate delays - allows symmetric distribution
                // This prevents right-skew that inflates P50 above the mean
                delay += p.meanMin + z0 * p.stdMin
            }
            // Only clamp the final result to prevent negative total travel times
            totals.append(max(0, Double(baseMinutes) + delay))
        }
        let sorted = totals.sorted()
        let p50 = Int(round(sorted[Int(Double(samples) * 0.5)]))
        let p90 = Int(round(sorted[Int(Double(samples) * 0.9)]))
        return (p50, p90)
    }
}
