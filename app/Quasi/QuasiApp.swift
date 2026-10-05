import SwiftUI

@main
struct QuasiApp: App {
    @StateObject private var model: AppModel
    @StateObject private var mac: MacServices

    init() {
        let model = AppModel()
        _model = StateObject(wrappedValue: model)
        _mac = StateObject(wrappedValue: MacServices(model: model))
    }

    var body: some Scene {
        MenuBarExtra {
            Text(model.connectionText)
            Text(model.syncStatus)
            Divider()
            Button("Download Stored Recordings") { model.requestSync() }
                .disabled(model.connection != .ready || model.phase == .recording)
            Button("Open Recordings Folder") { mac.openFolder() }
            Button("Show Transcript Window") { mac.showPanel() }
            Divider()
            Picker("Transcription Language", selection: $model.localeIdentifier) {
                ForEach(model.languageChoices, id: \.self) { identifier in
                    Text(Locale.current.localizedString(forIdentifier: identifier) ?? identifier).tag(identifier)
                }
            }
            Button(model.hasAnthropicKey ? "Change Anthropic API Key…" : "Set Anthropic API Key…") { mac.askForAnthropicKey() }
            Button(model.hasTodoistToken ? "Change Todoist API Token…" : "Set Todoist API Token…") { mac.askForTodoistToken() }
            Toggle("Launch at Login", isOn: $mac.launchAtLogin)
            Divider()
            Button("Quit Quasi") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        } label: {
            Image(systemName: model.phase == .recording ? "record.circle" : "waveform")
        }
    }
}
