import UIKit

/// Keeps the app running while it is in the background and the recorder is connected.
/// iOS wakes the app for every frame from the recorder but suspends it again within seconds,
/// which would stop the 10 s heartbeat and make the recorder drop the link. Each frame renews
/// a background task, so the heartbeat timer keeps firing and its reply renews the task again.
@MainActor
final class BackgroundLink {
    private var task: UIBackgroundTaskIdentifier = .invalid
    private var renewed = Date.distantPast

    /// Called for every frame, dozens of times a second while audio streams; a new task every
    /// few seconds is plenty, and asking for one each time cost processor time in the background.
    func renew() {
        let now = Date()
        guard task == .invalid || now.timeIntervalSince(renewed) >= 3 else { return }
        renewed = now
        let previous = task
        task = UIApplication.shared.beginBackgroundTask(withName: "Recorder link") { [weak self] in
            MainActor.assumeIsolated { self?.end() }
        }
        if previous != .invalid {
            UIApplication.shared.endBackgroundTask(previous)
        }
    }

    private func end() {
        guard task != .invalid else { return }
        UIApplication.shared.endBackgroundTask(task)
        task = .invalid
    }
}
