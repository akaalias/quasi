import ContactsUI
import SwiftUI

/// Everything that is set once and then left alone, in one sheet behind the gear.
struct SettingsSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage(StepSignals.soundsKey) private var sounds = true
    @AppStorage(StepSignals.tapsKey) private var taps = true
    @AppStorage(OnboardingFlow.doneKey) private var onboardingDone = true
    @State private var choosingContacts = false
    /// Access to Contacts can change in the phone's Settings while this sheet is up.
    @State private var contactsAccess = ContactBook.access

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // A sheet has no status bar above it, so the header makes its own room at the top.
                    HStack {
                        Text("Settings").typo(.screenTitle)
                        Spacer()
                        Button { dismiss() } label: { Text("Done").typo(Typo(size: 17.7, weight: .bold, tracking: 0.6)).foregroundStyle(Color.brand) }
                    }
                    .padding(.top, 22)
                    group("This build") {
                        row("Version", value: AppBuild.version)
                        Rule()
                        row("Commit", value: AppBuild.commit)
                        if let built = AppBuild.built {
                            Rule()
                            row("Built", value: built)
                        }
                    }
                    group("You") {
                        NavigationLink { NameScreen() } label: { row("Name", value: (model.userName.isEmpty ? "Not set" : model.userName) + " ›") }
                    }
                    group("Recorder") {
                        row("Comulytic Note Pro", value: recorder)
                        Rule()
                        if let storage = model.storage {
                            row("Free space", value: String(format: "%.1f of %.1f GB", Double(storage.free) / 1000, Double(storage.total) / 1000))
                            Rule()
                        }
                        if let stored = model.storedRecordings {
                            row("Recordings on it", value: "\(stored.count) · \(stored.megabytes < 10 ? String(format: "%.1f", stored.megabytes) : String(Int(stored.megabytes))) MB")
                            Rule()
                        }
                        Button { model.requestSync() } label: { row("Fetch stored recordings", value: "›") }
                            .disabled(model.connection != .ready || model.phase == .recording)
                    }
                    group("Understanding") {
                        NavigationLink { LanguageScreen() } label: { row("Language", value: language + " ›") }
                        Rule()
                        NavigationLink {
                            SecretScreen(title: "OpenAI", prompt: "OpenAI API key", isStored: model.hasOpenAIKey,
                                         explanation: "With an API key from your OpenAI account, each note is transcribed by OpenAI instead of on the phone, in whichever languages you spoke it. The recording is sent; the language above and the phone's languages are given as hints. Without network, the phone transcribes.") { model.setOpenAIKey($0) }
                        } label: { row("OpenAI", value: (model.hasOpenAIKey ? "Connected" : "Not set") + " ›") }
                        Rule()
                        NavigationLink {
                            SecretScreen(title: "Anthropic", prompt: "Anthropic API key", isStored: model.hasAnthropicKey,
                                         explanation: "With an API key from your Anthropic account, each transcript is sent to Claude, Anthropic's model, to find the tasks and messages you asked for.") { model.setAnthropicKey($0) }
                        } label: { row("Anthropic", value: (model.hasAnthropicKey ? "Connected" : "Not set") + " ›") }
                    }
                    group("Tasks") {
                        NavigationLink {
                            SecretScreen(title: "Todoist", prompt: "Todoist API token", isStored: model.hasTodoistToken,
                                         explanation: "With a token, a task you asked for is added to Todoist, filed under the project and labels you named.") { model.setTodoistToken($0) }
                        } label: { row("Todoist", value: (model.hasTodoistToken ? "Connected" : "Not set") + " ›") }
                    }
                    group("Messages") {
                        NavigationLink { RelayScreen() } label: { row("iMessage relay", value: (model.hasMessageRelay ? "Set up" : "Not set") + " ›") }
                        Rule()
                        // Who Quasi may message: a "Quasi" list in the Contacts app, if there is one. Failing that,
                        // with limited access the people are chosen here; the level itself (all, some, none) is the
                        // phone's to set.
                        if contactsAccess == .limited {
                            Button { choosingContacts = true } label: { row("Contacts", value: contacts + " ›") }
                        } else {
                            Link(destination: URL(string: UIApplication.openSettingsURLString)!) { row("Contacts", value: contacts + " ›") }
                        }
                        Rule()
                        Text("Only people in a list named “\(ContactBook.listName)” in the Contacts app can be messaged. Without such a list, everyone Quasi may see can.")
                            .typo(.ui).foregroundStyle(Color.quiet).padding(.vertical, 12)
                    }
                    group("Feedback") {
                        Toggle(isOn: $sounds) { Text("Sounds").typo(.ui) }.toggleStyle(SwitchStyle()).padding(.vertical, 12)
                        Rule()
                        Toggle(isOn: $taps) { Text("Taps").typo(.ui) }.toggleStyle(SwitchStyle()).padding(.vertical, 12)
                    }
                    group("Setup") {
                        // Walks through the name and the keys again; what is stored stays stored.
                        Button {
                            onboardingDone = false
                            dismiss()
                        } label: { row("Go through the setup again", value: "›") }
                    }
                }
                .padding(.horizontal, Metric.margin)
                .padding(.bottom, 40)
            }
            .foregroundStyle(Color.ink)
            .background(Color.paper)
            .toolbar(.hidden, for: .navigationBar)
            .contactAccessPicker(isPresented: $choosingContacts) { _ in }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                contactsAccess = ContactBook.access
            }
        }
        .tint(.brand)
    }

    private var recorder: String {
        switch model.connection {
        case .ready: return model.battery.map { "Nearby · \($0)%" } ?? "Nearby"
        case .bluetoothOff: return "Bluetooth is off"
        default: return "Out of reach"
        }
    }

    private var contacts: String {
        contactsAccess == .notDetermined ? "Not asked yet" : ContactBook.scope()
    }

    private var language: String {
        Locale.current.localizedString(forLanguageCode: model.locale.language.languageCode?.identifier ?? "") ?? model.localeIdentifier
    }

    private func group(_ title: String, @ViewBuilder rows: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased()).typo(.section).foregroundStyle(Color.quiet)
                .padding(.top, 18.3).padding(.bottom, 9.1).padding(.leading, 7.6)
            VStack(spacing: 0, content: rows)
                .padding(.horizontal, 19.8)
                .background(Color.card, in: RoundedRectangle(cornerRadius: Metric.radius))
        }
    }

    private func row(_ name: String, value: String) -> some View {
        HStack {
            Text(name).foregroundStyle(Color.ink)
            Spacer()
            Text(value).foregroundStyle(Color.quiet)
        }
        .typo(.ui)
        .padding(.vertical, 14.5)
        .contentShape(Rectangle())
    }
}

/// What the app calls its owner.
struct NameScreen: View {
    @EnvironmentObject private var model: AppModel
    @State private var draft = ""

    var body: some View {
        Form {
            Section {
                TextField("Your name", text: $draft)
                    .textContentType(.givenName).textInputAutocapitalization(.words).autocorrectionDisabled()
                    .onSubmit { model.userName = draft.trimmingCharacters(in: .whitespacesAndNewlines) }
            } footer: {
                Text("How the app addresses you.")
            }
            .listRowBackground(Color.card)
        }
        .scrollContentBackground(.hidden)
        .background(Color.paper)
        .navigationTitle("Name")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { draft = model.userName }
        .onDisappear { model.userName = draft.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
}

/// The language the recordings are transcribed in.
struct LanguageScreen: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        List(model.languageChoices, id: \.self) { identifier in
            Button {
                model.localeIdentifier = identifier
            } label: {
                HStack {
                    Text(Locale.current.localizedString(forIdentifier: identifier) ?? identifier).foregroundStyle(Color.ink)
                    Spacer()
                    if identifier == model.localeIdentifier { Image(systemName: "checkmark").foregroundStyle(Color.brand) }
                }
            }
            .listRowBackground(Color.card)
        }
        .scrollContentBackground(.hidden)
        .background(Color.paper)
        .navigationTitle("Language")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The three settings of the message relay (see MessageRelay.swift), and how the phone's own
/// automation has to be set up for it.
struct RelayScreen: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    SecretScreen(title: "Linq token", prompt: "Linq API token", isStored: Keychain.read(.linqToken) != nil,
                                 explanation: "The token of your Linq account, which has a line of its own.") { model.setRelaySetting($0, for: .linqToken) }
                } label: { LabeledContent("Linq token", value: Keychain.read(.linqToken) == nil ? "Not set" : "Stored") }
                NavigationLink {
                    SecretScreen(title: "Linq line", prompt: "+1 …", isStored: Keychain.read(.linqLine) != nil, isNumber: true,
                                 explanation: "The number Linq sends from.") { model.setRelaySetting($0, for: .linqLine) }
                } label: { LabeledContent("Linq line", value: Keychain.read(.linqLine) ?? "Not set") }
                NavigationLink {
                    SecretScreen(title: "Your number", prompt: "+49 …", isStored: Keychain.read(.ownNumber) != nil, isNumber: true,
                                 explanation: "This iPhone's own number, where the relay's text goes.") { model.setRelaySetting($0, for: .ownNumber) }
                } label: { LabeledContent("Your number", value: Keychain.read(.ownNumber) ?? "Not set") }
            } footer: {
                Text("""
                A message you ask for ("send a message to Alex that I'll be five minutes late") is sent from your own number \
                while the phone stays in your pocket. No app may send an iMessage itself, so Quasi texts this phone through Linq, \
                and an automation in Shortcuts sends it on. Set that up once by hand:

                Shortcuts → Automation → + → Message → Message Contains “\(MessageRelay.marker)|” → Run Immediately → Next → \
                the shortcut “Quasi Relay” (Split Text by “|”, Get Item 2, Get Item 3, Send Message with Show When Run off).
                """)
            }
            .listRowBackground(Color.card)
        }
        .scrollContentBackground(.hidden)
        .background(Color.paper)
        .navigationTitle("iMessage relay")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Entering or removing one key.
struct SecretScreen: View {
    let title: String
    let prompt: String
    let isStored: Bool
    /// A phone number rather than a secret: shown as typed, with the number keyboard.
    var isNumber = false
    let explanation: String
    let save: (String?) -> Void
    @State private var draft = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section {
                if isStored {
                    LabeledContent(prompt, value: "Stored in the keychain")
                    Button("Remove", role: .destructive) {
                        save(nil)
                        dismiss()
                    }
                } else {
                    if isNumber {
                        TextField(prompt, text: $draft).keyboardType(.phonePad)
                    } else {
                        SecureField(prompt, text: $draft)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    Button("Save") {
                        save(draft)
                        dismiss()
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } footer: {
                Text(explanation)
            }
            .listRowBackground(Color.card)
        }
        .scrollContentBackground(.hidden)
        .background(Color.paper)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Which build this is: the version with the build number, the commit, and when it was built. The
/// commit and the time are written into build-stamp.txt by the "Stamp the build" phase of the project.
enum AppBuild {
    private static let info = Bundle.main.infoDictionary ?? [:]
    private static let stamp: [String] = {
        guard let url = Bundle.main.url(forResource: "build-stamp", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").map(String.init)
    }()

    static var version: String {
        "\(info["CFBundleShortVersionString"] as? String ?? "?") (\(info["CFBundleVersion"] as? String ?? "?"))"
    }

    static var commit: String { stamp.first ?? "Unknown" }

    static var built: String? {
        guard stamp.count > 1, let date = ISO8601DateFormatter().date(from: stamp[1]) else { return nil }
        return date.formatted(.dateTime.day().month(.abbreviated).hour().minute())
    }
}
