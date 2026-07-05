import Foundation

struct JourneyPlan: Identifiable {
    let id = UUID()
    let legs: [RouteLeg]

    var totalDurationMinutes: Int { legs.reduce(0) { $0 + $1.durationMinutes } }

    /// Interchanges between adjacent transit legs. Staying on the same line
    /// (equal lineIds) is a continuation, not a change; when either id is
    /// unknown we can't prove it's the same service, so it counts.
    var changes: Int {
        let transit = legs.filter { $0.mode != .walk }
        return zip(transit, transit.dropFirst()).reduce(0) { count, pair in
            let (a, b) = pair
            let sameLine = a.lineId != nil && a.lineId == b.lineId
            return count + (sameLine ? 0 : 1)
        }
    }

    var walkMinutes: Int { legs.filter { $0.mode == .walk }.reduce(0) { $0 + $1.durationMinutes } }
}
