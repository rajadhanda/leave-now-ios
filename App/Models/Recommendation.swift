import Foundation

// MARK: - Core

public struct Recommendation: Identifiable, Equatable, Codable {
    public let id: UUID
    public let generatedAt: Date
    public let context: CommuteContext
    public let decision: LeaveDecision
    public let route: RouteAdvice
    public let fallback: RouteAdvice?
    public let variance: VarianceStats
    public let confidence: Confidence
    public let rationale: Rationale
    public let inputs: InputSnapshot
    public let ttlSeconds: Int
}

public struct CommuteContext: Codable, Equatable {
    public let origin: Place
    public let destination: Place
    public let habitualCommute: Bool
    public let window: DepartureWindow
}

public struct Place: Codable, Equatable {
    public let label: String
    public let geo: GeoPoint?
    public let transitStopID: String?
}

public struct GeoPoint: Codable, Equatable {
    public let lat: Double
    public let lon: Double
}

public struct DepartureWindow: Codable, Equatable {
    public let recommendedDeparture: Date?
    public let mode: DepartureMode
}

public enum DepartureMode: String, Codable { case now, inMinutes, waitMinutes }

public enum LeaveDecision: String, Codable {
    case leaveNow, leaveInMinutes, wait, takeFallback
}

// MARK: - Route Advice

public struct RouteAdvice: Codable, Equatable {
    public let label: String                 // "Northern → Jubilee"
    public let fingerprint: RouteFingerprint
    public let legs: [RouteLegSummary]
    public let changes: Int
    public let walkingMinutes: Int
    public let platformHint: String?
    public let comfort: ComfortTag?
}

public struct RouteFingerprint: Codable, Equatable, Hashable {
    public let lineSequence: [String]        // ["northern","jubilee"]
    public let stopIds: [String]?
}

public struct RouteLegSummary: Codable, Equatable {
    public let type: LegType
    public let lineOrService: String?
    public let approxMinutes: Int
}

public enum LegType: String, Codable { case walk, tube, rail, bus, tram, dlr, overground, elizabeth, ferry }

public enum ComfortTag: String, Codable { case fewerChanges, mostlySeated, weatherProtected, minimalWalking }

// MARK: - Uncertainty & Confidence

public struct VarianceStats: Codable, Equatable {
    public let etaP50Minutes: Int
    public let etaP90Minutes: Int
    public var tailRiskMinutes: Int { etaP90Minutes - etaP50Minutes }
}

public struct Confidence: Codable, Equatable {
    public let score: Double                 // 0.0–1.0
    public let level: ConfidenceLevel
    public let limitingFactors: [LimitingFactor]
}

public enum ConfidenceLevel: String, Codable { case low, medium, high }

public enum LimitingFactor: String, Codable {
    case liveDisruptionMissing, severeDisruptionNearby, weatherImpact, highInterchangeVariance, dataStale
}

// MARK: - Rationale

public struct Rationale: Codable, Equatable {
    public let oneLine: String
    public let highlights: [RationaleHighlight]
}

public struct RationaleHighlight: Codable, Equatable {
    public let kind: HighlightKind
    public let text: String
}

public enum HighlightKind: String, Codable { case weather, disruption, stability, preference }

// MARK: - Input Audit

public struct InputSnapshot: Codable, Equatable {
    public let dataFreshness: DataFreshness
    public let weather: WeatherImpact
    public let disruptions: [DisruptionImpact]
    public let priorsVersion: String
    public let weights: ScoringWeights
}

public struct DataFreshness: Codable, Equatable {
    public let transitUpdatedAt: Date?
    public let disruptionsUpdatedAt: Date?
    public let weatherUpdatedAt: Date?
}

public struct WeatherImpact: Codable, Equatable {
    public let raining: Bool
    public let rainIntensity: Double?        // 0–1
    public let walkingPenaltyMinutes: Int
    public let rainEndsAt: Date?
}

public struct DisruptionImpact: Codable, Equatable {
    public let line: String
    public let severity: DisruptionSeverity
    public let affectsPrimarySegment: Bool
    public let modeledDelayMeanMin: Double
    public let modeledDelayStdMin: Double
}

public enum DisruptionSeverity: String, Codable { case minor, moderate, severe }

public struct ScoringWeights: Codable, Equatable {
    public let alphaVariance: Double
    public let betaChanges: Double
    public let gammaWalking: Double
    public let deltaComfort: Double
}

// MARK: - Outcomes

public struct OutcomeEvent: Identifiable, Codable, Equatable {
    public let id: UUID
    public let recommendationId: UUID
    public let startedAt: Date
    public let endedAt: Date
    public let actualDurationMinutes: Int
    public let followedRoute: Bool
    public let departureDeltaMinutes: Int
    public let userArrivalJudgement: ArrivalJudgement?
    public let deviationIntent: DeviationIntent?
}

public enum ArrivalJudgement: String, Codable { case earlier, asExpected, later }

public enum DeviationIntent: String, Codable { case intentional, unintentional }
