import Foundation

struct TripSummary: Codable, Identifiable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date
    let selectedP50: Int
    let actualMinutes: Int?
    let changes: Int
}

final class TripHistoryStore: ObservableObject {
    static let shared = TripHistoryStore()
    @Published private(set) var trips: [TripSummary] = []

    private let url: URL
    private let queue = DispatchQueue(label: "TripHistoryStore")

    private init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        url = dir.appendingPathComponent("trip_history.json")
        load()
    }

    func add(start: Date, end: Date, p50: Int, actual: Int?, changes: Int) {
        let summary = TripSummary(id: UUID(), startedAt: start, endedAt: end, selectedP50: p50, actualMinutes: actual, changes: changes)
        trips.append(summary)
        persist()
    }

    func clear() {
        trips = []
        persist()
    }

    private func load() {
        guard let data = try? Data(contentsOf: url) else { return }
        if let decoded = try? JSONDecoder().decode([TripSummary].self, from: data) {
            trips = decoded
        }
    }

    private func persist() {
        queue.async { [trips] in
            if let data = try? JSONEncoder().encode(trips) {
                try? data.write(to: self.url)
            }
        }
    }
}
