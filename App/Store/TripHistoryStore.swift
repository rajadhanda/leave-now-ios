import Foundation

public protocol TripHistoryStore {
    /// Archives an outcome. When the current pending trip matches the
    /// outcome's `recommendationId`, the pair is stored together and the
    /// pending slot is cleared.
    mutating func save(outcome: OutcomeEvent) throws
    func recentOutcomes(limit: Int) throws -> [OutcomeEvent]

    /// Replaces the current pending prediction snapshot.
    mutating func savePending(_ trip: PendingTrip) throws
    func pendingTrip() throws -> PendingTrip?
    /// Stamps the pending trip's actual departure ("I've left").
    mutating func markDeparted(at date: Date) throws

    func recentTrips(limit: Int) throws -> [TripRecord]
}

public struct InMemoryTripHistoryStore: TripHistoryStore {
    private var records: [TripRecord] = []
    private var pending: PendingTrip?

    public init() {}

    public mutating func save(outcome: OutcomeEvent) throws {
        let trip = (pending?.id == outcome.recommendationId) ? pending : nil
        if trip != nil { pending = nil }
        records.append(TripRecord(outcome: outcome, trip: trip))
    }

    public func recentOutcomes(limit: Int) throws -> [OutcomeEvent] {
        records.suffix(limit).map(\.outcome)
    }

    public mutating func savePending(_ trip: PendingTrip) throws { pending = trip }
    public func pendingTrip() throws -> PendingTrip? { pending }
    public mutating func markDeparted(at date: Date) throws { pending?.actualDeparture = date }
    public func recentTrips(limit: Int) throws -> [TripRecord] { Array(records.suffix(limit)) }
}
