import SwiftUI

/// The charter's one-tap post-trip feedback. Which button set shows is
/// decided by route compliance (`OutcomeFeedback.buttonSet`): followed-route
/// trips rate the arrival, deviations rate intent. No free text.
struct TripFeedbackView: View {
    @ObservedObject var vm: RecommendationViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var followedRoute = true

    var body: some View {
        NavigationStack {
            Form {
                if let trip = vm.pendingTrip {
                    Section("Recommended route") {
                        Text(trip.routeLabel).font(.subheadline)
                    }
                }

                Section {
                    Toggle("I followed the recommended route", isOn: $followedRoute)
                }

                switch buttonSet {
                case .arrivalJudgement:
                    Section("Arrival vs prediction") {
                        Button("Earlier") { record(judgement: .earlier) }
                        Button("As expected") { record(judgement: .asExpected) }
                        Button("Later") { record(judgement: .later) }
                    }
                case .deviationIntent:
                    Section("Was the different route deliberate?") {
                        Button("Intentional") { record(intent: .intentional) }
                        Button("Unintentional") { record(intent: .unintentional) }
                    }
                }
            }
            .navigationTitle("Trip finished")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    /// v1 has no automatic route detection, so the toggle stands in for the
    /// actual fingerprint: on = same as recommended, off = a different one.
    private var buttonSet: OutcomeFeedback.ButtonSet {
        guard let trip = vm.pendingTrip else { return .arrivalJudgement }
        let actual = followedRoute
            ? trip.routeFingerprint
            : RouteFingerprint(lineSequence: [], stopIds: nil)
        return OutcomeFeedback.buttonSet(recommended: trip.routeFingerprint, actual: actual)
    }

    private func record(judgement: ArrivalJudgement? = nil, intent: DeviationIntent? = nil) {
        vm.recordOutcome(followedRoute: followedRoute, judgement: judgement, intent: intent)
        dismiss()
    }
}
