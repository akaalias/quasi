import ActivityKit
import Combine
import UIKit

/// Keeps the Live Activity (PhoneShared/RecorderActivity.swift) in step with the model.
///
/// While the recorder is connected the activity is refreshed every couple of minutes with a stale
/// date a few minutes ahead. If the app stops running, the refreshes stop and the Lock Screen
/// turns to "Lost contact" by itself.
@MainActor
final class RecorderActivityController {
    private static let refreshInterval: TimeInterval = 120
    private static let staleAfter: TimeInterval = 300

    private let model: AppModel
    private var activity: Activity<RecorderAttributes>?
    private var lastUpdate = Date.distantPast
    private var subscriptions: Set<AnyCancellable> = []

    init(model: AppModel) {
        self.model = model
        // Carry on with the activity of an earlier launch: after a relaunch in the background
        // (see Platform.bluetoothRestoreIdentifier) a new one could not be started.
        let earlier = Activity<RecorderAttributes>.activities
        activity = earlier.first
        for extra in earlier.dropFirst() {
            Task { await extra.end(nil, dismissalPolicy: .immediate) }
        }
        model.$connection.removeDuplicates().map { _ in () }
            .merge(with: model.$phase.removeDuplicates().map { _ in () },
                   model.$battery.removeDuplicates().map { _ in () })
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.update() }
            .store(in: &subscriptions)
        // An activity can only be started with the app in front, and the system ends it after
        // eight hours: start a fresh one whenever the app comes to the front without one.
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in self?.update() }
            .store(in: &subscriptions)
    }

    /// Called for every frame from the recorder; refreshes the activity now and then.
    func linkIsAlive() {
        if Date().timeIntervalSince(lastUpdate) >= Self.refreshInterval {
            update()
        }
    }

    private func update() {
        let now = Date()
        lastUpdate = now
        let status: RecorderAttributes.ContentState.Status
        switch (model.connection, model.phase) {
        case (.bluetoothOff, _): status = .bluetoothOff
        case (.ready, .recording): status = .recording
        case (_, .transcribing): status = .transcribing
        case (.ready, _): status = .connected
        default: status = .searching
        }
        let connected = model.connection == .ready
        let state = RecorderAttributes.ContentState(status: status, battery: model.battery,
                                                    recordingStart: model.recordingStart,
                                                    lastContact: connected ? now : (current?.lastContact ?? now))
        current = state
        let content = ActivityContent(state: state, staleDate: connected ? now.addingTimeInterval(Self.staleAfter) : nil)

        if let activity, activity.activityState == .active || activity.activityState == .stale {
            Task { await activity.update(content) }
        } else if UIApplication.shared.applicationState == .active, ActivityAuthorizationInfo().areActivitiesEnabled {
            activity = try? Activity.request(attributes: RecorderAttributes(), content: content)
        }
    }

    private var current: RecorderAttributes.ContentState?
}
