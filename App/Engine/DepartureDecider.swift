import Foundation

/// The output of a departure decision: what to tell the user and the departure
/// time it is based on.
struct DepartureDecision: Equatable {
    let decision: LeaveDecision
    let recommendedDeparture: Date
}

/// Turns an ETA into a "when to leave" decision — the product's core question.
///
/// The recommended departure is `arriveBy - P90` so the user arrives on time
/// with ~90% confidence. How far that is from now determines the verbict:
/// leave now / leave in N minutes / wait.
struct DepartureDecider {
    /// Within this many minutes of needing to leave, say "leave in N".
    var soonThresholdMinutes: Int = 10
    /// At or below this slack, just say "leave now".
    var leaveNowToleranceMinutes: Int = 1

    /// - Parameters:
    ///   - p90Minutes: the conservative (90th percentile) ETA.
    ///   - arriveBy: desired arrival time; if nil, default to leave-now.
    ///   - preferFallback: caller decided the fallback route should be taken
    ///     (e.g. a severe disruption hit the best route).
    func decide(now: Date, arriveBy: Date?, p90Minutes: Int, preferFallback: Bool) -> DepartureDecision {
        guard let arriveBy else {
            return DepartureDecision(decision: preferFallback ? .takeFallback : .leaveNow,
                                     recommendedDeparture: now)
        }

        let departBy = arriveBy.addingTimeInterval(TimeInterval(-p90Minutes * 60))
        let minutesUntilDeparture = Int((departBy.timeIntervalSince(now) / 60.0).rounded())

        let decision: LeaveDecision
        if preferFallback {
            decision = .takeFallback
        } else if minutesUntilDeparture <= leaveNowToleranceMinutes {
            decision = .leaveNow
        } else if minutesUntilDeparture <= soonThresholdMinutes {
            decision = .leaveInMinutes
        } else {
            decision = .wait
        }

        // Never recommend a departure in the past.
        return DepartureDecision(decision: decision, recommendedDeparture: max(now, departBy))
    }
}
