import Foundation

struct Recommendation {
    let plan: JourneyPlan
    let p50Minutes: Int
    let p90Minutes: Int
    let confidence: Double
    let rationale: String
}
