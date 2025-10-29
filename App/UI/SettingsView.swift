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
                Text("Configure α β γ δ in a later milestone")
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            }
        }
        .navigationTitle("Settings")
    }
}
