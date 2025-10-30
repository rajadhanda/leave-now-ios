import SwiftUI

struct LeaveNowView: View {
    @StateObject private var vm = RecommendationViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                RecommendationCard(vm: vm)
                    .padding()
            }
            .navigationTitle("Leave Now?")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await refresh() }
                    } label: { Image(systemName: "arrow.clockwise") }
                }
            }
            .task { await refresh() }
        }
    }

    private func refresh() async {
        // TODO: fetch recommendation from Engine (stub for now)
        vm.bind(Self.mockRecommendation())
    }
}

extension LeaveNowView {
    static func mockRecommendation() -> Recommendation {
        let now = Date()
        return Recommendation(
            id: .init(),
            generatedAt: now,
            context: .init(
                origin: .init(label: "Home", geo: nil, transitStopID: nil),
                destination: .init(label: "Office", geo: nil, transitStopID: nil),
                habitualCommute: true,
                window: .init(recommendedDeparture: Calendar.current.date(byAdding: .minute, value: 4, to: now), mode: .inMinutes)
            ),
            decision: .leaveInMinutes,
            route: .init(
                label: "Northern → Jubilee",
                fingerprint: .init(lineSequence: ["northern","jubilee"], stopIds: nil),
                legs: [
                    .init(type: .walk, lineOrService: nil, approxMinutes: 6),
                    .init(type: .tube, lineOrService: "Northern", approxMinutes: 12),
                    .init(type: .tube, lineOrService: "Jubilee", approxMinutes: 10),
                    .init(type: .walk, lineOrService: nil, approxMinutes: 4)
                ],
                changes: 1, walkingMinutes: 10, platformHint: nil, comfort: .minimalWalking
            ),
            fallback: .init(
                label: "Bus 24 → District",
                fingerprint: .init(lineSequence: ["bus24","district"], stopIds: nil),
                legs: [ .init(type: .bus, lineOrService: "Bus 24", approxMinutes: 18) ],
                changes: 2, walkingMinutes: 7, platformHint: nil, comfort: .fewerChanges
            ),
            variance: .init(etaP50Minutes: 32, etaP90Minutes: 39),
            confidence: .init(score: 0.82, level: .high, limitingFactors: [.weatherImpact]),
            rationale: .init(oneLine: "Light rain adds +2m walking; no delays on your segment.", highlights: []),
            inputs: .init(
                dataFreshness: .init(transitUpdatedAt: now, disruptionsUpdatedAt: now, weatherUpdatedAt: now),
                weather: .init(raining: true, rainIntensity: 0.3, walkingPenaltyMinutes: 2),
                disruptions: [],
                priorsVersion: "priors-v0.3.2",
                weights: .init(alphaVariance: 0.7, betaChanges: 2.0, gammaWalking: 0.3, deltaComfort: 1.0)
            ),
            ttlSeconds: 300
        )
    }
}

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
