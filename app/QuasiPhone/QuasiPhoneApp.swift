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
        // app, which saves typing them on the phone. They are stored in the keychain like typed ones.
        let environment = ProcessInfo.processInfo.environment
        if let key = environment["ANTHROPIC_API_KEY"], !key.isEmpty { model.setAnthropicKey(key) }
        if let token = environment["TODOIST_API_TOKEN"], !token.isEmpty { model.setTodoistToken(token) }
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
        let signals = StepSignals()
        model.onLiveStep = { signals.play($0) }
    }

    var body: some Scene {
        WindowGroup {
            LogScreen().environmentObject(model)
                // Again whenever the phone is unlocked with the app in front, in case the first try came too early.
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    Platform.openForBackgroundUse()
                }
        }
    }
}
