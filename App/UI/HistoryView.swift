import SwiftUI

struct HistoryView: View {
    // Placeholder view until trip history is implemented

    var body: some View {
        VStack(spacing: 12) {
            Text("Trip history")
                .font(.headline)
            Text("No trips to display yet.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("History")
    }
}
