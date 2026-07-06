import Foundation

/// Auto-captured prediction snapshot awaiting its real-world outcome — the
/// charter's capture-on-recommend fields: recommended departure time, route
/// fingerprint, and predicted arrival P50/P90.
public struct PendingTrip: Identifiable, Codable, Equatable {
    /// Same as the `Recommendation`'s id, keying the outcome to its prediction.
    public let id: UUID
    public let createdAt: Date
    public let recommendedDeparture: Date?
    public let routeFingerprint: RouteFingerprint
    public let routeLabel: String
    public let predictedP50Minutes: Int
    public let predictedP90Minutes: Int
    /// Set when the user taps "I've left".
    public var actualDeparture: Date?
}

/// A finished trip: the outcome joined to the prediction it answers.
/// `trip` is nil for outcomes recorded without a captured prediction.
public struct TripRecord: Identifiable, Codable, Equatable {
    public var id: UUID { outcome.id }
    public let outcome: OutcomeEvent
    public let trip: PendingTrip?
}

/// The charter's structured one-tap post-trip feedback: if the recommended
/// route was followed the user rates the arrival, otherwise they rate the
/// deviation. No free text.
public enum OutcomeFeedback {
    public enum ButtonSet: Equatable {
        /// [ Earlier ] [ As Expected ] [ Later ]
        case arrivalJudgement
        /// [ Intentional ] [ Unintentional ]
        case deviationIntent
    }

    /// A nil actual fingerprint means no deviation was detected or reported,
    /// which counts as following the route.
    public static func followedRoute(recommended: RouteFingerprint, actual: RouteFingerprint?) -> Bool {
        guard let actual else { return true }
        return actual == recommended
    }

    public static func buttonSet(recommended: RouteFingerprint, actual: RouteFingerprint?) -> ButtonSet {
        followedRoute(recommended: recommended, actual: actual) ? .arrivalJudgement : .deviationIntent
    }
}
