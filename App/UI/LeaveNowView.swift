import SwiftUI

struct LeaveNowView: View {
    @State private var destination: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "location.fill")
                    Text("Origin: Current location")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                TextField("Destination", text: $destination)
                    .textFieldStyle(.roundedBorder)
                Button("Leave now?") {
                    // TODO: trigger recommendation
                }
                .buttonStyle(.borderedProminent)
                RecommendationCard()
                Spacer()
            }
            .padding()
            .navigationTitle("Leave Now?")
        }
    }
}

struct RecommendationCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recommendation")
                .font(.headline)
            Text("P50: —  P90: —  Confidence: —")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Rationale: —")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }
}
