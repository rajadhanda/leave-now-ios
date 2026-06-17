import SwiftUI
import Foundation

struct LeaveNowView: View {
    @StateObject private var vm = RecommendationViewModel()
    @State private var showTripEditor = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                tripHeader
                RecommendationCard(vm: vm)
            }
            .padding()
        }
        .navigationTitle("Leave Now?")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await vm.refresh() } } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(vm.isLoading)
            }
        }
        .refreshable { await vm.refresh() }
        .task { await vm.refresh() }
        // Re-evaluate with the new trip whenever the editor is dismissed.
        .sheet(isPresented: $showTripEditor, onDismiss: { Task { await vm.refresh() } }) {
            TripEditView()
        }
    }

    /// Tappable summary of the current trip; opens the editor.
    private var tripHeader: some View {
        Button { showTripEditor = true } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(UserPrefs.shared.originPostcode)  →  \(UserPrefs.shared.destinationPostcode)")
                        .font(.subheadline).bold()
                    if UserPrefs.shared.arriveByEnabled {
                        Text("Arrive by \(arriveByText)")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Leave-now mode")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "pencil.circle").foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var arriveByText: String {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return df.string(from: UserPrefs.shared.arriveBy)
    }
}

/// Lets the user edit origin/destination and an optional target arrival time.
/// These drive the recommendation and the leave-now/wait decision.
struct TripEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var origin = UserPrefs.shared.originPostcode
    @State private var destination = UserPrefs.shared.destinationPostcode
    @State private var arriveByEnabled = UserPrefs.shared.arriveByEnabled
    @State private var arriveBy = UserPrefs.shared.arriveBy

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip") {
                    DestinationPicker("Origin postcode", text: $origin)
                    DestinationPicker("Destination postcode", text: $destination)
                }
                Section("Timing") {
                    Toggle("I need to arrive by a time", isOn: $arriveByEnabled)
                    if arriveByEnabled {
                        DatePicker("Arrive by", selection: $arriveBy, displayedComponents: .hourAndMinute)
                    }
                }
            }
            .navigationTitle("Edit trip")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        UserPrefs.shared.originPostcode = origin.trimmingCharacters(in: .whitespacesAndNewlines)
                        UserPrefs.shared.destinationPostcode = destination.trimmingCharacters(in: .whitespacesAndNewlines)
                        UserPrefs.shared.arriveByEnabled = arriveByEnabled
                        UserPrefs.shared.arriveBy = arriveBy
                        dismiss()
                    }.bold()
                }
            }
        }
    }
}
