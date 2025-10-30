import SwiftUI

struct RecommendationCard: View {
    @ObservedObject var vm: RecommendationViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LEAVE NOW?").font(.headline).foregroundStyle(.secondary)

            Text(vm.title).font(.title2).bold()
            Text(vm.subtitle).font(.subheadline).foregroundStyle(.secondary)

            HStack {
                Text(vm.p50Text)
                Spacer()
                Text(vm.p90Text)
            }
            .font(.subheadline)

            Text(vm.confidenceText)
                .font(.subheadline)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(confidenceTint())
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Divider()

            Text("Route: \(vm.routeLabel)")
                .font(.subheadline)

            Text("Reason: \(vm.rationale)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let hint = vm.rec?.route.platformHint, !hint.isEmpty {
                Divider()
                Text(hint)
                    .font(.subheadline)
            }

            if vm.hasFallback {
                Button {
                    // Expand fallback overlay (to implement)
                } label: {
                    Text("View fallback (slower, safer)")
                        .font(.callout)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 1)
    }

    private func confidenceTint() -> Color {
        guard let score = vm.rec?.confidence.score else { return .gray.opacity(0.2) }
        switch score {
        case 0.7...: return .green.opacity(0.15)
        case 0.5..<0.7: return .blue.opacity(0.15)
        default: return .orange.opacity(0.15)
        }
    }
}


