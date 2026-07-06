import Foundation

struct Disruption: Identifiable {
    let id = UUID()
    let lineId: String
    let affectedStations: Set<String>
    let severity: DisruptionSeverity
}

extension DisruptionSeverity {
    /// Ordering for "worst disruption wins" comparisons — the one shared
    /// definition (previously duplicated in the recommender and TfL service).
    var rank: Int {
        switch self {
        case .minor: return 1
        case .moderate: return 2
        case .severe: return 3
        }
    }
}
