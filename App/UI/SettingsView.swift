import SwiftUI

struct SettingsView: View {
    @State private var rainSensitivity = UserPrefs.shared.rainSensitivity
    @State private var alpha = UserPrefs.shared.alphaVariance
    @State private var beta = UserPrefs.shared.betaChanges
    @State private var gamma = UserPrefs.shared.gammaWalking
    @State private var delta = UserPrefs.shared.deltaComfort

    var body: some View {
        Form {
            Section("Sensitivity") {
                labeledSlider("Rain sensitivity", value: $rainSensitivity, range: 0...1, step: 0.05) {
                    UserPrefs.shared.rainSensitivity = $0
                }
            }

            Section {
                labeledSlider("α — variance penalty", value: $alpha, range: 0...2, step: 0.05) {
                    UserPrefs.shared.alphaVariance = $0
                }
                labeledSlider("β — changes penalty", value: $beta, range: 0...5, step: 0.1) {
                    UserPrefs.shared.betaChanges = $0
                }
                labeledSlider("γ — walking penalty", value: $gamma, range: 0...2, step: 0.05) {
                    UserPrefs.shared.gammaWalking = $0
                }
                labeledSlider("δ — comfort bonus", value: $delta, range: 0...3, step: 0.05) {
                    UserPrefs.shared.deltaComfort = $0
                }
            } header: {
                Text("Scoring weights (advanced)")
            } footer: {
                Text("Higher α/β/γ make the app avoid variance, changes and walking; δ rewards more comfortable routes. Changes apply on the next refresh.")
            }
        }
        .navigationTitle("Settings")
    }

    @ViewBuilder
    private func labeledSlider(_ title: String,
                               value: Binding<Double>,
                               range: ClosedRange<Double>,
                               step: Double,
                               onCommit: @escaping (Double) -> Void) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: value, in: range, step: step)
                .onChange(of: value.wrappedValue) { _, newValue in onCommit(newValue) }
        }
    }
}
