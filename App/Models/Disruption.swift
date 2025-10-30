import Foundation

struct Disruption: Identifiable {
    let id = UUID()
    let lineId: String
    let affectedStations: Set<String>
    let severity: DisruptionSeverity
}
