import Foundation

final class RecommendationViewModel: ObservableObject {

    @Published private(set) var rec: Recommendation?

    init(rec: Recommendation? = nil) { self.rec = rec }

    func bind(_ r:  Recommendation) { self.rec = r }

    // UI-mapped strings
    var title: String {
        guard let r = rec else { return "LEAVE NOW?" }
        switch r.decision {
        case .leaveNow: return "✅ Leave now"
        case .leaveInMinutes:
            if let mins = leaveInMinutes { return "✅ Leave in ~\(mins) min" }
            return "✅ Leave soon"
        case .wait:
            if let mins = waitMinutes { return "⏳ Wait ~\(mins) min" }
            return "⏳ Wait a bit"
        case .takeFallback:
            return "⚠️ Switch to fallback"
        }
    }

    var subtitle: String {
        guard let r = rec else { return "Checking conditions…" }
        return r.context.habitualCommute ? "Your usual route is stable today." : "Familiar route suggested."
    }

    var p50Text: String {
        guard let r = rec else { return "--" }
        let base = "ETA: \(r.variance.etaP50Minutes) min (P50)"
        let rainPenalty = r.inputs.weather.walkingPenaltyMinutes
        if rainPenalty > 0 {
            if let end = r.inputs.weather.rainEndsAt {
                let df = DateFormatter()
                df.dateFormat = "HH:mm"
                return base + " (+\(rainPenalty)m due to rain, until \(df.string(from: end)))"
            }
            return base + " (+\(rainPenalty)m due to rain)"
        }
        return base
    }
    var p90Text: String { rec.map { "Worst case: \($0.variance.etaP90Minutes) min (P90)" } ?? "--" }

    var confidenceText: String {
        guard let r = rec else { return "--" }
        let pct = Int(r.confidence.score * 100.0)
        let level = r.confidence.level.rawValue.capitalized
        return "Confidence: \(pct)% • \(level) risk"
    }

    var routeLabel: String { rec?.route.label ?? "" }
    var rationale: String { rec?.rationale.oneLine ?? "" }

    var hasFallback: Bool { rec?.fallback != nil }
    var fallbackLabel: String {
        guard let fb = rec?.fallback else { return "" }
        return "Fallback: \(fb.label) (slower, more stable)"
    }

    private var leaveInMinutes: Int? {
        guard let r = rec else { return nil }
        guard r.decision == .leaveInMinutes, let ts = r.context.window.recommendedDeparture else { return nil }
        let mins = Int(round(ts.timeIntervalSinceNow / 60.0))
        return max(mins, 0)
    }

    private var waitMinutes: Int? {
        guard let r = rec else { return nil }
        guard r.decision == .wait, let ts = r.context.window.recommendedDeparture else { return nil }
        let mins = Int(round(ts.timeIntervalSinceNow / 60.0))
        return max(mins, 0)
    }
}


