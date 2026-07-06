import Foundation

/// Persistent trip history: a single JSON file in Application Support —
/// zero-ceremony storage that survives relaunch, which is all v1 needs.
/// Loads once on init and rewrites atomically on every mutation (history is
/// a few records per day, so whole-file writes are fine).
public final class JSONTripHistoryStore: TripHistoryStore {
    private struct State: Codable {
        var pending: PendingTrip?
        var records: [TripRecord] = []
    }

    public static let shared = JSONTripHistoryStore()

    private let fileURL: URL
    private var state: State

    /// Pass an explicit URL in tests; the default lives in
    /// `Application Support/LeaveNow/trip-history.json`.
    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
        self.state = Self.load(from: self.fileURL)
    }

    // MARK: - TripHistoryStore

    public func save(outcome: OutcomeEvent) throws {
        let trip = (state.pending?.id == outcome.recommendationId) ? state.pending : nil
        if trip != nil { state.pending = nil }
        state.records.append(TripRecord(outcome: outcome, trip: trip))
        try persist()
    }

    public func recentOutcomes(limit: Int) throws -> [OutcomeEvent] {
        state.records.suffix(limit).map(\.outcome)
    }

    public func savePending(_ trip: PendingTrip) throws {
        state.pending = trip
        try persist()
    }

    public func pendingTrip() throws -> PendingTrip? { state.pending }

    public func markDeparted(at date: Date) throws {
        state.pending?.actualDeparture = date
        try persist()
    }

    public func recentTrips(limit: Int) throws -> [TripRecord] {
        Array(state.records.suffix(limit))
    }

    // MARK: - Persistence

    private static func defaultFileURL() -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LeaveNow", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("trip-history.json")
    }

    // A corrupt or missing file just means empty history.
    private static func load(from url: URL) -> State {
        guard let data = try? Data(contentsOf: url),
              let state = try? decoder.decode(State.self, from: data) else { return State() }
        return state
    }

    private func persist() throws {
        try Self.encoder.encode(state).write(to: fileURL, options: .atomic)
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
