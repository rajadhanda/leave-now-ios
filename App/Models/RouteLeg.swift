import Foundation

enum LegMode: String { case walk, tube, bus, overground, dlr, nationalRail, car }

struct RouteLeg: Identifiable {
    let id = UUID()
    let mode: LegMode
    let lineId: String?
    let fromStation: String?
    let toStation: String?
    let durationMinutes: Int
}
