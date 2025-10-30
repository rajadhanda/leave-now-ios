import SwiftUI

struct HistoryView: View {
    // Placeholder view until history store is implemented for UI

    var body: some View {
        VStack(spacing: 12) {
            Text("Trip History")
                .font(.headline)
            Text("No history yet")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("History")
    }
}
