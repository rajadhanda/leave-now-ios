import SwiftUI

struct RecommendationCard: View {
    @ObservedObject var vm: RecommendationViewModel
    @State private var showFallback = false
    @State private var reminder: ReminderState = .idle
    @State private var showTripFeedback = false

    private enum ReminderState: Equatable { case idle, scheduled, denied }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if case .sample = vm.source, let msg = vm.statusMessage {
                Label(msg, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.yellow.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

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

            if let hint = vm.rec?.route.platformHint, !hint.isEmpty {
                Text("Directions")
                    .font(.subheadline).bold()
                Text(hint)
                    .font(.subheadline)
            }

            Text("Reason: \(vm.rationale)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            reminderButton
            tripProgressButton

            if vm.hasFallback {
                Divider()
                Button {
                    withAnimation { showFallback.toggle() }
                } label: {
                    HStack {
                        Text(showFallback ? "Hide fallback" : "View fallback (slower, safer)")
                        Spacer()
                        Image(systemName: showFallback ? "chevron.up" : "chevron.down")
                    }
                    .font(.callout)
                }
                .buttonStyle(.bordered)

                if showFallback, let fb = vm.rec?.fallback {
                    fallbackDetail(fb)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 1)
        .sheet(isPresented: $showTripFeedback) {
            TripFeedbackView(vm: vm)
        }
    }

    /// Outcome capture (charter loop): "I've left" stamps the departure,
    /// "I've arrived" opens the one-tap feedback.
    @ViewBuilder
    private var tripProgressButton: some View {
        if let trip = vm.pendingTrip {
            if trip.actualDeparture == nil {
                Button {
                    vm.markDeparted()
                } label: {
                    Label("I've left", systemImage: "figure.walk")
                        .font(.callout)
                }
                .buttonStyle(.bordered)
            } else {
                Button {
                    showTripFeedback = true
                } label: {
                    Label("I've arrived", systemImage: "checkmark.circle")
                        .font(.callout)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder
    private var reminderButton: some View {
        Button {
            Task {
                let ok = await vm.scheduleLeaveReminder()
                reminder = ok ? .scheduled : .denied
            }
        } label: {
            Label(reminderTitle, systemImage: reminder == .scheduled ? "bell.fill" : "bell")
                .font(.callout)
        }
        .buttonStyle(.borderedProminent)
        .disabled(reminder == .scheduled || vm.rec == nil)
    }

    private var reminderTitle: String {
        switch reminder {
        case .idle: return "Remind me when to leave"
        case .scheduled: return "Reminder set"
        case .denied: return "Enable notifications in Settings"
        }
    }

    @ViewBuilder
    private func fallbackDetail(_ fb: RouteAdvice) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(fb.label).font(.subheadline).bold()
            Text("\(fb.changes) change\(fb.changes == 1 ? "" : "s") • \(fb.walkingMinutes)m walking")
                .font(.caption).foregroundStyle(.secondary)
            ForEach(Array(fb.legs.enumerated()), id: \.offset) { item in
                Text("• \(legText(item.element))").font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private func legText(_ leg: RouteLegSummary) -> String {
        let mode = leg.type.rawValue.capitalized
        if let line = leg.lineOrService, !line.isEmpty {
            return "\(mode) \(line) — ~\(leg.approxMinutes)m"
        }
        return "\(mode) — ~\(leg.approxMinutes)m"
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
