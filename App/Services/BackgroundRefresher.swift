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

    /// Ask the system to run us again later (best-effort; the OS decides timing).
    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    /// Recompute and notify if the user should be leaving now/soon.
    @MainActor
    static func handle() async {
        let vm = RecommendationViewModel()
        await vm.refresh()
        await vm.notifyIfDepartureImminent()
    }
}
