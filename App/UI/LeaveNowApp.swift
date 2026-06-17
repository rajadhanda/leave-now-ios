import SwiftUI

@main
struct LeaveNowApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// Top-level tab navigation. Previously the app only ever showed `LeaveNowView`,
/// so Settings and History (which existed) were unreachable.
struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack { LeaveNowView() }
                .tabItem { Label("Leave", systemImage: "figure.walk") }

            NavigationStack { HistoryView() }
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }

            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
