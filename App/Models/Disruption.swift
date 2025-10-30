import Foundation

public enum DisruptionSeverity: String, Codable { case minor, moderate, severe }

struct Disruption: Identifiable {
    let id = UUID()
    let lineId: String
    let affectedStations: Set<String>
    let severity: DisruptionSeverity
}
