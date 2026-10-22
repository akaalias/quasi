import AlarmKit
import SwiftUI

enum TimerClockError: LocalizedError {
    case notAllowed

    var errorDescription: String? {
        switch self {
        case .notAllowed: return "Quasi is not allowed to set timers. Allow it in Settings → Apps → Quasi."
        }
    }
}

/// Starts countdowns with AlarmKit: they show on the Lock Screen and ring like the Clock app's
/// timer, even with Quasi closed.
enum TimerClock {
    static var isAllowed: Bool { AlarmManager.shared.authorizationState == .authorized }
    static var isUndecided: Bool { AlarmManager.shared.authorizationState == .notDetermined }

    /// Asks for permission the first time. Has to be called with the app in front.
    @discardableResult
    static func requestAccess() async -> Bool {
        (try? await AlarmManager.shared.requestAuthorization()) == .authorized
    }

    /// Starts the timer and returns its id.
    static func start(_ timer: TimerDraft) async throws -> String {
        guard isAllowed else { throw TimerClockError.notAllowed }
        let title: LocalizedStringResource = timer.label.isEmpty ? "Timer" : "\(timer.label)"
        let presentation = AlarmPresentation(
            alert: .init(title: title, stopButton: AlarmButton(text: "Done", textColor: .white, systemImageName: "checkmark")),
            countdown: .init(title: title, pauseButton: AlarmButton(text: "Pause", textColor: .orange, systemImageName: "pause.fill")),
            paused: .init(title: "Paused", resumeButton: AlarmButton(text: "Resume", textColor: .orange, systemImageName: "play.fill")))
        let attributes = AlarmAttributes(presentation: presentation, metadata: QuasiTimer(label: timer.label), tintColor: .orange)
        let id = UUID()
        _ = try await AlarmManager.shared.schedule(id: id, configuration: .timer(duration: TimeInterval(timer.seconds), attributes: attributes))
        return id.uuidString
    }

    static func cancel(_ id: String) {
        guard let uuid = UUID(uuidString: id) else { return }
        try? AlarmManager.shared.cancel(id: uuid)
    }
}
