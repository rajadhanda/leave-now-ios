import Foundation

struct JourneyPlan: Identifiable {
    let id = UUID()
    let legs: [RouteLeg]

    var totalDurationMinutes: Int { legs.reduce(0) { $0 + $1.durationMinutes } }
    var changes: Int { max(0, legs.filter { $0.mode != .walk }.count - 1) }
    var walkMinutes: Int { legs.filter { $0.mode == .walk }.reduce(0) { $0 + $1.durationMinutes } }
}
