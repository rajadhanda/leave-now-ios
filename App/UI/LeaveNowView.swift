import SwiftUI

struct LeaveNowView: View {
    @State private var best: Recommendation? = nil
    @State private var fallback: Recommendation? = nil
    @State private var showFallback: Bool = false
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
                DestinationPicker(destination: $destination)
                    .textFieldStyle(.roundedBorder)
                Button("Leave now?") {
                    if let result = BacktestHarness.run() {
                    best = result.best
                    fallback = result.fallback
                }
                }
                .buttonStyle(.borderedProminent)
                RecommendationCardView(best: best, fallback: showFallback ? fallback : nil, onToggleFallback: { showFallback.toggle() })
                Spacer()
            }
            .padding()
            .navigationTitle("Leave Now?")
        }
    }
}

struct RecommendationCardView: View {
    let best: Recommendation?
    let fallback: Recommendation?
    let onToggleFallback: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recommendation")
                .font(.headline)
            if let rec = best {
                Text("P50: \(rec.p50Minutes)m  P90: \(rec.p90Minutes)m  Confidence: \(Int(rec.confidence * 100))%")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Rationale: \(rec.rationale)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if let fb = fallback {
                    Button("Show fallback") { onToggleFallback() }
                        .buttonStyle(.bordered)
                    Text("Fallback: P50 \(fb.p50Minutes)m / P90 \(fb.p90Minutes)m, conf \(Int(fb.confidence * 100))%")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Button("Show fallback") { onToggleFallback() }
                        .buttonStyle(.bordered)
                        .disabled(true)
                }
                Button("Notify if plan changes in next 10 min") {
                    // TODO: schedule local notification in a later milestone
                }.buttonStyle(.bordered)
            } else {
                Text("P50: —  P90: —  Confidence: —")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Rationale: —")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }
}
