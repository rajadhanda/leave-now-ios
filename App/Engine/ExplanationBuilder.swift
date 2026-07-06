import Foundation

/// Builds the one-line, human-readable rationale shown under a recommendation.
/// All inputs are facts about a *specific* route, so the fallback route gets its
/// own (honest) rationale rather than inheriting the best route's.
struct ExplanationBuilder {
    /// - Parameters:
    ///   - isFastest: whether this route has the best (lowest) median ETA of the
    ///     candidates. Only the chosen route should claim "Fastest median".
    ///   - rainDelta: extra walking minutes attributed to rain (0 = none).
    ///   - hasSevereDelaysOnKeyLeg: a severe disruption affects a line on this route.
    ///   - keyLineName: the disrupted line on this route, or nil if none.
    func rationale(p50: Int,
                   p90: Int,
                   changes: Int,
                   rainDelta: Int,
                   hasSevereDelaysOnKeyLeg: Bool,
                   keyLineName: String?,
                   isFastest: Bool) -> String {
        var parts: [String] = []
        if isFastest { parts.append("Fastest median") }
        parts.append(ConfidenceModel.isStable(spreadMinutes: p90 - p50) ? "stable variance" : "±\(p90 - p50)m variance")
        parts.append("\(changes) change\(changes == 1 ? "" : "s")")
        if rainDelta > 0 { parts.append("rain adds +\(rainDelta)m walking") }
        if let line = keyLineName {
            parts.append(hasSevereDelaysOnKeyLeg ? "severe delays on \(line)" : "delays on \(line)")
        } else {
            parts.append("no active delays")
        }
        return parts.joined(separator: ", ") + "."
    }
}
