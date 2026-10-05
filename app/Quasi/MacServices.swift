import AppKit
import ServiceManagement

/// The Mac-only behaviour around the shared model: the floating panel, launch at login, and
/// telling the model when nobody is at the Mac.
@MainActor
final class MacServices: ObservableObject {
    @Published var launchAtLogin = SMAppService.mainApp.status == .enabled {
        didSet {
            guard launchAtLogin != (SMAppService.mainApp.status == .enabled) else { return }
            do {
                if launchAtLogin { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                model.syncStatus = "Launch at login failed: \(error.localizedDescription)"
            }
        }
    }

    private let model: AppModel
    private let panel = LivePanelController()

    // The link is held only while someone is at the Mac: not while the screen is locked, the
    // display is off or the Mac sleeps.
    private var screenLocked = false
    private var displayAsleep = false

    init(model: AppModel) {
        self.model = model
        model.onLiveSessionStarted = { [weak self] in self?.showPanel() }
        observePresence()
    }

    func showPanel() {
        panel.show(model: model)
    }

    func openFolder() {
        NSWorkspace.shared.open(model.folder)
    }

    /// Asks for the key that lets transcripts be checked for tasks. An empty answer removes it.
    func askForAnthropicKey() {
        askForSecret(title: "Anthropic API Key", isStored: model.hasAnthropicKey,
                     explanation: "With a key, each transcript is sent to Claude to find a task you asked for.") {
            self.model.setAnthropicKey($0)
        }
    }

    /// Asks for the token that lets a task found be added to Todoist. An empty answer removes it.
    func askForTodoistToken() {
        askForSecret(title: "Todoist API Token", isStored: model.hasTodoistToken,
                     explanation: "With a token, a task found in a transcript is added to your Todoist inbox.") {
            self.model.setTodoistToken($0)
        }
    }

    private func askForSecret(title: String, isStored: Bool, explanation: String, save: (String) -> Void) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = explanation + " It is kept in your keychain. Leave the field empty to remove it."
        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        field.placeholderString = isStored ? "One is stored" : ""
        alert.accessoryView = field
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            save(field.stringValue)
        }
    }

    private func observePresence() {
        if let session = CGSessionCopyCurrentDictionary() as? [String: Any] {
            screenLocked = session["CGSSessionScreenIsLocked"] as? Bool ?? false
        }
        let workspace = NSWorkspace.shared.notificationCenter
        let distributed = DistributedNotificationCenter.default()
        let changes: [(NotificationCenter, Notification.Name, (MacServices) -> Void)] = [
            (workspace, NSWorkspace.willSleepNotification, { $0.model.systemIsAsleep = true }),
            (workspace, NSWorkspace.didWakeNotification, { $0.model.systemIsAsleep = false }),
            (workspace, NSWorkspace.screensDidSleepNotification, { $0.displayAsleep = true }),
            (workspace, NSWorkspace.screensDidWakeNotification, { $0.displayAsleep = false }),
            (distributed, Notification.Name("com.apple.screenIsLocked"), { $0.screenLocked = true }),
            (distributed, Notification.Name("com.apple.screenIsUnlocked"), { $0.screenLocked = false }),
        ]
        for (center, name, apply) in changes {
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    apply(self)
                    self.model.userIsAway = self.screenLocked || self.displayAsleep
                }
            }
        }
        model.userIsAway = screenLocked || displayAsleep
    }
}
