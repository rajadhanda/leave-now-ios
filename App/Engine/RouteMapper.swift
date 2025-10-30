import Foundation

struct RouteMapper {
    static func mapCandidateToRouteAdvice(_ candidate: JourneyCandidate) -> RouteAdvice {
        let platformHint = candidate.rail?.meta.departure.platform ?? candidate.platformHint
        let legs: [RouteLegSummary] = zip(candidate.lineSequence, candidate.legsMinutes).map { line, mins in
            let type: LegType = line.lowercased().contains("rail") ? .rail : .tube
            return RouteLegSummary(type: type, lineOrService: line, approxMinutes: mins)
        }
        return RouteAdvice(
            label: candidate.label,
            fingerprint: .init(lineSequence: candidate.lineSequence, stopIds: nil),
            legs: legs,
            changes: candidate.changes,
            walkingMinutes: candidate.walkingMinutes,
            platformHint: platformHint,
            comfort: nil
        )
    }
}


