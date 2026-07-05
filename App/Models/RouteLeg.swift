import Foundation

enum LegMode: String { case walk, tube, bus, overground, dlr, nationalRail, car }

struct RouteLeg: Identifiable {
    let id = UUID()
    let mode: LegMode
    /// Canonical lowercased line identifier (e.g. "northern") — used for
    /// disruption matching and route fingerprints, never for display.
    let lineId: String?
    /// Human-readable line name (e.g. "Northern") — used for labels only.
    let lineName: String?
    let fromStation: String?
    let toStation: String?
    let durationMinutes: Int

    init(mode: LegMode,
         lineId: String?,
         lineName: String? = nil,
         fromStation: String?,
         toStation: String?,
         durationMinutes: Int) {
        self.mode = mode
        self.lineId = lineId
        self.lineName = lineName
        self.fromStation = fromStation
        self.toStation = toStation
        self.durationMinutes = durationMinutes
    }
}
