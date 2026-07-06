import Foundation

/// Single source of truth for how the P50→P90 spread (tail risk, in minutes)
/// maps to a confidence score, a level, and the "stable variance" wording.
/// The engine score, the UI level badge, and the rationale phrase must all
/// read from here so they can never contradict each other (e.g. "stable
/// variance" alongside "Medium risk").
enum ConfidenceModel {
    /// Spread at or below which a route is called "stable variance".
    /// 3 minutes ≤ spread implies score ≥ 0.94, i.e. always a high level.
    static let stableSpreadMinutes = 3
    /// Spread at which the score bottoms out at zero.
    static let zeroScoreSpreadMinutes = 50.0
    /// Exclusive lower score bounds for the level buckets.
    static let highScoreThreshold = 0.75
    static let mediumScoreThreshold = 0.5

    /// Linear falloff: 1 at zero spread, 0 at `zeroScoreSpreadMinutes`.
    static func score(spreadMinutes: Int) -> Double {
        max(0.0, min(1.0, 1.0 - Double(spreadMinutes) / zeroScoreSpreadMinutes))
    }

    /// The level is derived from the score, which is derived from the spread —
    /// one chain, so level and score always agree.
    static func level(spreadMinutes: Int) -> ConfidenceLevel {
        let s = score(spreadMinutes: spreadMinutes)
        if s > highScoreThreshold { return .high }
        if s > mediumScoreThreshold { return .medium }
        return .low
    }

    static func isStable(spreadMinutes: Int) -> Bool {
        spreadMinutes <= stableSpreadMinutes
    }
}
