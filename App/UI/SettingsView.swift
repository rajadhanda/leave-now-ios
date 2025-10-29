import SwiftUI

struct SettingsView: View {
    @State private var rainSensitivity: Double = UserPrefs.shared.rainSensitivity

    var body: some View {
        Form {
            Section("Sensitivity") {
                HStack {
                    Text("Rain sensitivity")
                    Spacer()
                    Text(String(format: "%.2f", rainSensitivity))
                        .foregroundStyle(.secondary)
                }
                Slider(value: $rainSensitivity, in: 0.05...0.12, step: 0.01)
                    .onChange(of: rainSensitivity) { _, newValue in
                        UserPrefs.shared.rainSensitivity = newValue
                    }
            }
            Section("Weights (Advanced)") {
                VStack(alignment: .leading) {
                    Text("α (variance weight)")
                    Slider(value: .constant(0.7), in: 0...2)
                    Text("β (changes penalty)")
                    Slider(value: .constant(2.0), in: 0...5)
                    Text("γ (walk penalty)")
                    Slider(value: .constant(0.3), in: 0...2)
                    Text("δ (comfort bonus)")
                    Slider(value: .constant(1.0), in: 0...3)
                }
            }
        }
        .navigationTitle("Settings")
    }
}
