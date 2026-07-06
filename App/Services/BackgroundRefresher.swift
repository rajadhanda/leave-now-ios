import Foundation
import BackgroundTasks

/// Drives the passive/proactive mode: periodically recompute the recommendation
/// in the background and, when it's time to leave, fire a local notification.
///
/// The launch handler is registered by SwiftUI's `.backgroundTask(.appRefresh:)`
/// modifier on the app scene; this type only submits the next request and does
/// the work. The identifier must match `BGTaskSchedulerPermittedIdentifiers` in
/// Info.plist.
enum BackgroundRefresher {
    static let taskIdentifier = "com.example.LeaveNow.refresh"

    /// Ask the system to run us again later. `.backgroundTask(.appRefresh:)`
    /// registration plus this submit is strictly best-effort: the OS throttles
    /// app-refresh tasks on its own schedule (usage patterns, battery, Low
    /// Power Mode), so `earliestBeginDate` is a floor, not an appointment.
    /// Delivery can only be verified on-device — see the debug log in
    /// `handle()`.
    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    /// Recompute and notify if the user should be leaving now/soon. Never
    /// prompts for notification authorization — `notifyIfDepartureImminent`
    /// schedules only when already authorized.
    @MainActor
    static func handle() async {
        let vm = RecommendationViewModel()
        await vm.refresh()
        await vm.notifyIfDepartureImminent()
        #if DEBUG
        // On-device verification aid: shows up in Console.app when the OS
        // actually grants us a background slot.
        print("BackgroundRefresher: ran at \(Date()), decision=\(vm.rec?.decision.rawValue ?? "none")")
        #endif
    }
}
