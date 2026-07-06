import SwiftUI

/// Recent trips from the persistent store: predicted vs actual duration plus
/// the one-tap post-trip result, newest first.
struct HistoryView: View {
    @State private var records: [TripRecord] = []

    var body: some View {
        Group {
            if records.isEmpty {
                ContentUnavailableView(
                    "No trips yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Tap “I've left” and “I've arrived” on a recommendation to build history.")
                )
            } else {
                List(records.reversed()) { record in
                    HistoryRow(record: record)
                }
            }
        }
        .navigationTitle("History")
        .onAppear {
            records = (try? JSONTripHistoryStore.shared.recentTrips(limit: 50)) ?? []
        }
    }
}

private struct HistoryRow: View {
    let record: TripRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(record.trip?.routeLabel ?? "Trip")
                    .font(.subheadline).bold()
                Spacer()
                Text(record.outcome.endedAt, format: .dateTime.day().month().hour().minute())
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let trip = record.trip {
                Text("Predicted \(trip.predictedP50Minutes)–\(trip.predictedP90Minutes) min • Actual \(record.outcome.actualDurationMinutes) min")
                    .font(.caption)
            } else {
                Text("Actual \(record.outcome.actualDurationMinutes) min")
                    .font(.caption)
            }
            Text(resultText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var resultText: String {
        if record.outcome.followedRoute {
            switch record.outcome.userArrivalJudgement {
            case .earlier: return "Followed route • arrived earlier"
            case .asExpected: return "Followed route • as expected"
            case .later: return "Followed route • arrived later"
            case nil: return "Followed route"
            }
        }
        switch record.outcome.deviationIntent {
        case .intentional: return "Different route • intentional"
        case .unintentional: return "Different route • unintentional"
        case nil: return "Different route"
        }
    }
}
