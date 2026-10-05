import UIKit

/// Keeps the app running while it is in the background and the recorder is connected.
/// iOS wakes the app for every frame from the recorder but suspends it again within seconds,
/// which would stop the 10 s heartbeat and make the recorder drop the link. Each frame renews
/// a background task, so the heartbeat timer keeps firing and its reply renews the task again.
@MainActor
final class BackgroundLink {
    private var task: UIBackgroundTaskIdentifier = .invalid

    func renew() {
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
