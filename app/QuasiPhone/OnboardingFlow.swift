import SwiftUI

/// The first run: who you are, then the keys the app needs, one per screen. Whatever is already
/// in the keychain is kept and shown as connected; nothing is ever cleared here. Shown once after
/// install; Settings can bring it back.
struct OnboardingFlow: View {
    static let doneKey = "onboardingDone"

    @EnvironmentObject private var model: AppModel
    @AppStorage(OnboardingFlow.doneKey) private var done = false
    @State private var step = Step.name
    @State private var name = ""

    enum Step: Int, CaseIterable {
        case name, openAI, claude, todoist, relay, ready
        var next: Step? { Step(rawValue: rawValue + 1) }
        var previous: Step? { Step(rawValue: rawValue - 1) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if step != .ready {
                    Text("Step \(step.rawValue + 1) of \(Step.ready.rawValue)").typo(.section).foregroundStyle(Color.quiet)
                }
                Spacer()
                if let previous = step.previous, step != .ready {
                    Button("Back") { withAnimation { step = previous } }.buttonStyle(PillStyle())
                }
            }
            .padding(.top, 8)
            Group {
                switch step {
                case .name:
                    NameStep(name: $name) { finish(name: name) }
                case .openAI:
                    KeyStep(title: "Add your OpenAI key",
                            text: "OpenAI turns your recordings into text, and it handles you switching languages mid-sentence. Paste a key from your OpenAI account here. The recording is sent, nothing else.",
                            prompt: "OpenAI API key", isStored: model.hasOpenAIKey, help: ("platform.openai.com", "https://platform.openai.com/api-keys"),
                            check: KeyCheck.openAI, save: model.setOpenAIKey, advance: advance)
                case .claude:
                    KeyStep(title: "Now your Claude key",
                            text: "Claude reads each transcript and picks out the tasks and messages you asked for. Paste a key from your Anthropic account here.",
                            prompt: "Claude API key", isStored: model.hasAnthropicKey, help: ("console.anthropic.com", "https://console.anthropic.com/settings/keys"),
                            check: KeyCheck.anthropic, save: model.setAnthropicKey, advance: advance)
                case .todoist:
                    KeyStep(title: "Do you use Todoist?",
                            text: "If you do, paste your Todoist API token and every task Claude finds lands there, in the project and with the labels you mentioned. If not, skip this; tasks are still shown in the app.",
                            prompt: "Todoist API token", isStored: model.hasTodoistToken, help: ("Todoist › Settings › Integrations", "https://app.todoist.com/app/settings/integrations/developer"),
                            check: KeyCheck.todoist, save: model.setTodoistToken, skippable: true, advance: advance)
                case .relay:
                    RelayStep(advance: advance)
                case .ready:
                    ReadyStep(name: model.userName) { done = true }
                }
            }
            .id(step)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
        }
        .padding(.horizontal, Metric.margin)
        .padding(.bottom, 24)
        .foregroundStyle(Color.ink)
        .background(Color.paper)
        .onAppear { name = model.userName }
    }

    private func finish(name: String) {
        model.userName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        advance()
    }

    private func advance() {
        if let next = step.next { withAnimation { step = next } }
    }
}

/// The title and the paragraph under it, the same on every step.
private struct StepHeading: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).typo(.day).padding(.top, 36).padding(.bottom, Metric.gap)
            Text(text).typo(.ui).foregroundStyle(Color.quiet)
        }
    }
}

/// The filled button that moves on.
private struct ContinueButton: View {
    let title: String
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title).typo(.uiStrong).foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .background(enabled ? Color.brand : Color.rule, in: Capsule())
        }
        .disabled(!enabled)
    }
}

private struct NameStep: View {
    @Binding var name: String
    let advance: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StepHeading(title: "What's your name?", text: "Quasi writes down what you say into the recorder, finds what you asked for, and does it. Let's get it set up, starting with you.")
            TextField("Your name", text: $name)
                .typo(.ui).textContentType(.givenName).textInputAutocapitalization(.words).autocorrectionDisabled()
                .submitLabel(.next).focused($focused).onSubmit { if ready { advance() } }
                .padding(.horizontal, 19.8).padding(.vertical, 12)
                .background(Color.card, in: RoundedRectangle(cornerRadius: Metric.radius))
                .padding(.top, 28)
            Spacer()
            ContinueButton(title: "Next", enabled: ready, action: advance)
        }
        .onAppear { focused = name.isEmpty }
    }

    private var ready: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }
}

/// One key: shown as connected if the keychain has it, asked for otherwise. A key typed in is
/// checked with the service before it is kept, so a typo shows up here and not in a note later.
private struct KeyStep: View {
    let title: String
    let text: String
    let prompt: String
    let isStored: Bool
    /// Where the key comes from, as a link.
    let help: (String, String)
    let check: (String) async -> KeyCheck.Result
    let save: (String?) -> Void
    var skippable = false
    let advance: () -> Void

    @State private var draft = ""
    @State private var replacing = false
    @State private var checking = false
    @State private var problem: String?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StepHeading(title: title, text: text)
            VStack(alignment: .leading, spacing: 0) {
                if isStored && !replacing {
                    HStack {
                        Text("Connected").typo(.ui)
                        Spacer()
                        Button("Use a different one") { replacing = true; focused = true }.buttonStyle(PillStyle())
                    }
                    .padding(.vertical, 8)
                } else {
                    SecureField(prompt, text: $draft)
                        .typo(.ui).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .submitLabel(.next).focused($focused).onSubmit { submit() }
                        .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 19.8).padding(.vertical, 6)
            .background(Color.card, in: RoundedRectangle(cornerRadius: Metric.radius))
            .padding(.top, 28)
            if let problem {
                Text(problem).typo(.ui).foregroundStyle(Color.brand).padding(.top, Metric.gap)
            } else if !isStored || replacing {
                HStack(spacing: 4) {
                    Text("You can make one at").typo(.ui).foregroundStyle(Color.quiet)
                    Link(help.0, destination: URL(string: help.1)!).typo(.ui).foregroundStyle(Color.brand)
                }
                .padding(.top, Metric.gap)
            }
            Spacer()
            HStack(spacing: Metric.gap) {
                if skippable && !isStored {
                    Button("Skip") { advance() }.buttonStyle(PillStyle())
                }
                ContinueButton(title: checking ? "Checking…" : "Next", enabled: ready && !checking, action: submit)
            }
        }
        .onAppear { focused = !isStored }
    }

    private var ready: Bool { (isStored && !replacing) || !draft.trimmingCharacters(in: .whitespaces).isEmpty }

    private func submit() {
        guard ready, !checking else { return }
        if isStored && !replacing {
            advance()
            return
        }
        let key = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        checking = true
        problem = nil
        Task {
            let result = await check(key)
            checking = false
            switch result {
            case .accepted, .unreachable:
                save(key)
                advance()
            case .rejected(let reason):
                problem = reason
            }
        }
    }
}

/// The three settings of the message relay, all or none. The shortcut and automation on the
/// phone are set up by hand, as the setup page explains.
private struct RelayStep: View {
    @EnvironmentObject private var model: AppModel
    let advance: () -> Void
    @State private var token = ""
    @State private var replacingToken = false
    @State private var line = Keychain.read(.linqLine) ?? ""
    @State private var ownNumber = Keychain.read(.ownNumber) ?? ""
    private let tokenStored = Keychain.read(.linqToken) != nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                StepHeading(title: "Want messages sent from your own number?", text: "Say \"send Anna a message that I'm running late\" and it goes out as an iMessage from you, with the phone still in your pocket. This needs a Linq account and a shortcut you set up once by hand. You can skip it for now.")
                VStack(spacing: 0) {
                    if tokenStored && !replacingToken {
                        HStack {
                            Text("Linq token").typo(.ui)
                            Spacer()
                            Button("Replace") { replacingToken = true }.buttonStyle(PillStyle())
                        }
                        .padding(.vertical, 8)
                    } else {
                        SecureField("Linq API token", text: $token).typo(.ui).textInputAutocapitalization(.never).autocorrectionDisabled().padding(.vertical, 8)
                    }
                    Rule()
                    TextField("Linq line, +1 …", text: $line).typo(.ui).keyboardType(.phonePad).padding(.vertical, 8)
                    Rule()
                    TextField("Your number, +49 …", text: $ownNumber).typo(.ui).keyboardType(.phonePad).padding(.vertical, 8)
                }
                .padding(.horizontal, 19.8).padding(.vertical, 6)
                .background(Color.card, in: RoundedRectangle(cornerRadius: Metric.radius))
                .padding(.top, 28)
                HStack(spacing: 4) {
                    Text("How to set up the shortcut:").typo(.ui).foregroundStyle(Color.quiet)
                    Link("setup page", destination: URL(string: "https://alexisrondeau.me/quasi/setup.html#messages")!).typo(.ui).foregroundStyle(Color.brand)
                }
                .padding(.top, Metric.gap)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        Spacer(minLength: 0)
        HStack(spacing: Metric.gap) {
            if !complete {
                Button("Skip") { advance() }.buttonStyle(PillStyle())
            }
            ContinueButton(title: "Next", enabled: complete) {
                if !token.trimmingCharacters(in: .whitespaces).isEmpty { model.setRelaySetting(token, for: .linqToken) }
                model.setRelaySetting(line, for: .linqLine)
                model.setRelaySetting(ownNumber, for: .ownNumber)
                advance()
            }
        }
        }
    }

    private var complete: Bool {
        let hasToken = (tokenStored && !replacingToken) || !token.trimmingCharacters(in: .whitespaces).isEmpty
        return hasToken && !line.trimmingCharacters(in: .whitespaces).isEmpty && !ownNumber.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

private struct ReadyStep: View {
    @EnvironmentObject private var model: AppModel
    let name: String
    let start: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StepHeading(title: name.isEmpty ? "You're all set." : "You're all set, \(name).", text: "Press record on the recorder and say what's on your mind. The note shows up here, with what was done about it. Everything you just entered can be changed later behind the gear.")
            VStack(spacing: 0) {
                line("Transcription", model.hasOpenAIKey ? "OpenAI" : "On the phone")
                Rule()
                line("Understanding", model.hasAnthropicKey ? "Claude" : "Not set")
                Rule()
                line("Tasks", model.hasTodoistToken ? "Todoist" : "Shown only")
                Rule()
                line("Messages", model.hasMessageRelay ? "Through your number" : "Not set")
            }
            .padding(.horizontal, 19.8).padding(.vertical, 6)
            .background(Color.card, in: RoundedRectangle(cornerRadius: Metric.radius))
            .padding(.top, 28)
            Spacer()
            ContinueButton(title: "Let's go", action: start)
        }
    }

    private func line(_ what: String, _ how: String) -> some View {
        HStack {
            Text(what).typo(.ui)
            Spacer()
            Text(how).typo(.ui).foregroundStyle(Color.quiet)
        }
        .padding(.vertical, 8)
    }
}

/// Asks each service whether a key is good, with the cheapest request it has.
enum KeyCheck {
    enum Result {
        case accepted
        case rejected(String)
        /// No answer from the service: the key is kept and judged by its first real use.
        case unreachable
    }

    static func openAI(_ key: String) async -> Result {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/models")!)
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        return await probe(request, rejected: "OpenAI does not accept this key.")
    }

    static func anthropic(_ key: String) async -> Result {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/models")!)
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        return await probe(request, rejected: "Anthropic does not accept this key.")
    }

    static func todoist(_ token: String) async -> Result {
        var request = URLRequest(url: URL(string: "https://api.todoist.com/api/v1/projects?limit=1")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return await probe(request, rejected: "Todoist does not accept this token.")
    }

    private static func probe(_ request: URLRequest, rejected: String) async -> Result {
        var request = request
        request.timeoutInterval = 15
        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let status = (response as? HTTPURLResponse)?.statusCode else { return .unreachable }
        switch status {
        case 200..<300: return .accepted
        case 401, 403: return .rejected(rejected)
        default: return .unreachable
        }
    }
}
