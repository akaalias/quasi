import SwiftUI

/// Everything that is set once and then left alone, in one sheet behind the gear.
struct SettingsSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage(StepSignals.soundsKey) private var sounds = true
    @AppStorage(StepSignals.tapsKey) private var taps = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Settings").typo(.screenTitle)
                        Spacer()
                        Button { dismiss() } label: { Text("Done").typo(Typo(size: 17.7, weight: .bold, tracking: 0.6)).foregroundStyle(Color.brand) }
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
                            SecretScreen(title: "Claude", prompt: "Claude API key", isStored: model.hasAnthropicKey,
                                         explanation: "With a key, each transcript is sent to Claude to find a task you asked for.") { model.setAnthropicKey($0) }
                        } label: { row("Claude", value: (model.hasAnthropicKey ? "Connected" : "Not set") + " ›") }
                    }
                    group("Tasks") {
                        NavigationLink {
                            SecretScreen(title: "Todoist", prompt: "Todoist API token", isStored: model.hasTodoistToken,
                                         explanation: "With a token, a task you asked for is added to Todoist, filed under the project and labels you named.") { model.setTodoistToken($0) }
                        } label: { row("Todoist", value: (model.hasTodoistToken ? "Connected" : "Not set") + " ›") }
                    }
                    group("Feedback") {
                        Toggle(isOn: $sounds) { Text("Sounds").typo(.ui) }.toggleStyle(SwitchStyle()).padding(.vertical, 12)
                        Rule()
                        Toggle(isOn: $taps) { Text("Taps").typo(.ui) }.toggleStyle(SwitchStyle()).padding(.vertical, 12)
                    }
                }
                .padding(.horizontal, Metric.margin)
                .padding(.top, 2)
                .padding(.bottom, 40)
            }
            .foregroundStyle(Color.ink)
            .background(Color.paper)
            .toolbar(.hidden, for: .navigationBar)
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

/// Entering or removing one key.
struct SecretScreen: View {
    let title: String
    let prompt: String
    let isStored: Bool
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
                    SecureField(prompt, text: $draft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
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
