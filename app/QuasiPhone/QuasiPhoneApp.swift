import SwiftUI

@main
struct QuasiPhoneApp: App {
    @StateObject private var model: AppModel
    private let backgroundLink = BackgroundLink()
    private let activity: RecorderActivityController
    private let lockScreen: LockScreenPublisher

    init() {
        Platform.openForBackgroundUse()
        let model = AppModel()
        // For development: `tools/phone.sh` passes the secrets from `.env` when it launches the
        // app, which saves typing them on the phone. They only fill in what the phone does not
        // have yet: a key typed on the phone is never replaced by an older one from the Mac.
        let environment = ProcessInfo.processInfo.environment
        func fill(_ name: String, _ secret: Keychain.Secret, _ store: (String) -> Void) {
            if let value = environment[name], !value.isEmpty, Keychain.read(secret) == nil { store(value) }
        }
        fill("ANTHROPIC_API_KEY", .anthropicKey) { model.setAnthropicKey($0) }
        fill("OPENAI_API_KEY", .openAIKey) { model.setOpenAIKey($0) }
        fill("TODOIST_API_TOKEN", .todoistToken) { model.setTodoistToken($0) }
        for (name, secret) in [("LINQ_API_TOKEN", Keychain.Secret.linqToken), ("LINQ_FROM", .linqLine), ("LINQ_TO", .ownNumber)] {
            fill(name, secret) { model.setRelaySetting($0, for: secret) }
        }
        // `-demo home|live|note|settings` at launch shows a staged state (see tools/screens.sh).
        if let demo = UserDefaults.standard.string(forKey: "demo") {
            model.stage(connection: .ready, battery: 82, recording: demo == "live")
        }
        let activity = RecorderActivityController(model: model)
        _model = StateObject(wrappedValue: model)
        self.activity = activity
        let lockScreen = LockScreenPublisher(model: model)
        self.lockScreen = lockScreen
        model.onLinkActivity = { [backgroundLink] in
            backgroundLink.renew()
            activity.linkIsAlive()
            lockScreen.linkIsAlive()
        }
        // Woken before the phone's first unlock, the app cannot read its log yet: it reads it as soon as it can.
        NotificationCenter.default.addObserver(forName: UIApplication.protectedDataDidBecomeAvailableNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { model.loadLog() }
        }
        model.startTimer = { try await TimerClock.start($0) }
        let signals = StepSignals()
        model.onLiveStep = { signals.play($0) }
    }

    var body: some Scene {
        WindowGroup {
            LogScreen().environmentObject(model)
                // Again whenever the phone is unlocked with the app in front, in case the first try came too early.
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    Platform.openForBackgroundUse()
                    model.loadLog()
                    // Contacts can only be asked for with the app in front; messages are looked up in the background.
                    if model.hasMessageRelay, ContactBook.access == .notDetermined {
                        Task { _ = await ContactBook.requestAccess() }
                    }
                    // Reminders and timers are asked for in the pocket, where no permission can be asked.
                    // One question at a time, and only once each.
                    if model.hasAnthropicKey {
                        Task {
                            if ReminderBook.isUndecided { await ReminderBook.requestAccess() }
                            if TimerClock.isUndecided { await TimerClock.requestAccess() }
                        }
                    }
                }
        }
    }
}
