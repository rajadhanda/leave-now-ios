import SwiftUI

struct HistoryView: View {
    var body: some View {
        List {
            Text("No history yet")
                .foregroundStyle(.secondary)
        }
        .navigationTitle("History")
    }
}
