import Foundation

struct ExplanationBuilder {
    func rationale(p50: Int, p90: Int, changes: Int, rainDelta: Int, hasSevereDelaysOnKeyLeg: Bool, keyLineName: String?) -> String {
        var parts: [String] = []
        if p50 > 0 { parts.append("Fastest median") }
        if p90 - p50 <= 3 { parts.append("stable variance") }
        parts.append("\(changes) change\(changes == 1 ? "" : "s")")
        if rainDelta > 0 { parts.append("Light rain adds +\(rainDelta)m walking") }
        if let line = keyLineName {
            parts.append("\(hasSevereDelaysOnKeyLeg ? "Severe delays" : "No active delays") on \(line) segment")
        }
        return parts.joined(separator: ", ") + "."
    }
}
