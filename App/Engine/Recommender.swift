import Foundation

public struct UtilityWeights {
    public let alphaVariance: Double
    public let betaChanges: Double
    public let gammaWalking: Double
    public let deltaComfort: Double
}

public struct RouteScore {
    public let utility: Double
    public let p50: Int
    public let p90: Int
}

public protocol Recommender {
    func scoreRoute(p50: Int, p90: Int, changes: Int, walkingMinutes: Int, comfortBonus: Double, w: UtilityWeights) -> RouteScore
}

public struct DefaultRecommender: Recommender {
    public init() {}
    public func scoreRoute(p50: Int, p90: Int, changes: Int, walkingMinutes: Int, comfortBonus: Double, w: UtilityWeights) -> RouteScore {
        let variance = max(0, p90 - p50)
        let util = Double(p50)
            + w.alphaVariance * Double(variance)
            + w.betaChanges * Double(changes)
            + w.gammaWalking * Double(walkingMinutes)
            - w.deltaComfort * comfortBonus
        return .init(utility: util, p50: p50, p90: p90)
    }
}
