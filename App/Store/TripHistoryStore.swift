import Foundation

public protocol TripHistoryStore {
    mutating func save(outcome: OutcomeEvent) throws
    func recentOutcomes(limit: Int) throws -> [OutcomeEvent]
}

public struct InMemoryTripHistoryStore: TripHistoryStore {
    private var items: [OutcomeEvent] = []
    public init() {}
    public func recentOutcomes(limit: Int) throws -> [OutcomeEvent] { Array(items.suffix(limit)) }
    public mutating func save(outcome: OutcomeEvent) throws { items.append(outcome) }
}
