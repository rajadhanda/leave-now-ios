import SwiftUI

struct HistoryView: View {
    @ObservedObject var store = TripHistoryStore.shared

    var body: some View {
        List(store.trips) { trip in
            VStack(alignment: .leading) {
                Text("P50: \(trip.selectedP50)m  Changes: \(trip.changes)")
                Text("Start: \(trip.startedAt.formatted())  End: \(trip.endedAt.formatted())")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }.navigationTitle("History")
        .toolbar {
            Button("Clear history") { store.clear() }
        }
    }
}
