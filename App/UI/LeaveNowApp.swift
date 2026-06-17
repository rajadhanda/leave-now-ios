import SwiftUI

@main
struct LeaveNowApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        // Passive/proactive mode: when the OS grants us background time, recompute
        // and (if it's time to leave) notify, then ask for the next slot.
        .backgroundTask(.appRefresh(BackgroundRefresher.taskIdentifier)) {
            await BackgroundRefresher.handle()
            BackgroundRefresher.schedule()
        }
    }
}

/// Top-level tab navigation. Previously the app only ever showed `LeaveNowView`,
/// so Settings and History (which existed) were unreachable.
struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            NavigationStack { LeaveNowView() }
                .tabItem { Label("Leave", systemImage: "figure.walk") }

            NavigationStack { HistoryView() }
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }

            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        // Queue a background refresh whenever we leave the foreground.
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { BackgroundRefresher.schedule() }
        }
    }
}
