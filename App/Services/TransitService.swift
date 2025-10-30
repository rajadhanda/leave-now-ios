import Foundation

public struct JourneyCandidate {
    public let label: String
    public let lineSequence: [String]
    public let legsMinutes: [Int]
    public let changes: Int
    public let walkingMinutes: Int
    public let platformHint: String?
}

public protocol TransitService {
    func candidates(origin: String, destination: String, departure: Date) async throws -> [JourneyCandidate]
    func disruptions() async throws -> [String: DisruptionSeverity] // keyed by line id
}
