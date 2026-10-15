import SwiftUI

/// Home: every recording, newest first, each as the speaker's own words and one line saying
/// what became of them. Live capture rises over it as a sheet; settings sit behind one button.
struct LogScreen: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingSettings = UserDefaults.standard.string(forKey: "demo") == "settings"
    @State private var liveDismissed = false
    @State private var path: [String] = []
    /// The first run asks for the name and the keys; the demo states skip it.
    @AppStorage(OnboardingFlow.doneKey) private var onboardingDone = UserDefaults.standard.string(forKey: "demo") != nil

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Button { showingSettings = true } label: { RecorderBadge(connection: model.connection, battery: model.battery) }
                            .buttonStyle(.plain)
                        Spacer()
                        Button { showingSettings = true } label: {
                            Image(systemName: "gearshape.fill").font(.system(size: 14.5, weight: .semibold)).foregroundStyle(Color.ink)
                                .frame(width: 30.4, height: 30.4)
                                .background(Color.chip, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Settings")
                    }
                    if model.notes.isEmpty {
                        ContentUnavailableView("No notes yet", systemImage: "waveform",
                                               description: Text("Press record on the recorder. Your note appears here, with what was done about it."))
                            .padding(.top, 80)
                    }
                    ForEach(Array(days.enumerated()), id: \.element.day) { index, group in
                        Text(group.title)
                            .typo(index == 0 ? .day : .earlierDay)
                            .padding(.top, index == 0 ? 11.4 : 30.5)
                            .padding(.bottom, Metric.gap)
                        ForEach(group.notes) { note in
                            NavigationLink(value: note.id) { NoteRow(note: note) }
                                .buttonStyle(.plain)
                            if note.id != group.notes.last?.id {
                                Rule().padding(.vertical, Metric.gap)
                            }
                        }
                    }
                }
                .padding(.horizontal, Metric.margin)
                .padding(.top, 2.7)
                .padding(.bottom, 40)
            }
            .foregroundStyle(Color.ink)
            .background(Color.paper)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: String.self) { NoteScreen(id: $0) }
            .fullScreenCover(isPresented: Binding(get: { !onboardingDone }, set: { onboardingDone = !$0 })) { OnboardingFlow() }
            .sheet(isPresented: $showingSettings) { SettingsSheet() }
            .sheet(isPresented: live) { LiveSheet() }
            .onAppear {
                if UserDefaults.standard.string(forKey: "demo") == "note", path.isEmpty,
                   let note = model.notes.first(where: { $0.outcome == .taskAdded }) {
                    path = [note.id]
                }
            }
            .onChange(of: model.phase) { _, phase in
                if phase == .recording { liveDismissed = false }
            }
        }
        .tint(.brand)
    }

    /// The live view is up while a note is being recorded or transcribed, unless it was swiped away.
    private var live: Binding<Bool> {
        Binding(get: { (model.phase == .recording || model.phase == .transcribing) && !liveDismissed && !showingSettings },
                set: { if !$0 { liveDismissed = true } })
    }

    private var days: [(day: Date, title: String, notes: [NoteRecord])] {
        let calendar = Calendar.current
        return Dictionary(grouping: model.notes) { calendar.startOfDay(for: $0.date) }
            .sorted { $0.key > $1.key }
            .map { day, notes in
                let title = calendar.isDateInToday(day) ? "Today" : calendar.isDateInYesterday(day) ? "Yesterday"
                    : day.formatted(.dateTime.weekday(.wide).day().month(.wide))
                return (day, title, notes)
            }
    }
}

/// One entry of the log.
struct NoteRow: View {
    let note: NoteRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(note.date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))).typo(.ui).foregroundStyle(Color.quiet)
            switch note.outcome {
            case .noAudio:
                words("A recording was made, but its audio did not reach the phone.", spoken: false)
                Text("It is still on the recorder.").typo(.ui).foregroundStyle(Color.quiet)
            case .transcriptionFailed:
                words("This recording could not be transcribed.", spoken: false)
                Text("It is still on the recorder.").typo(.ui).foregroundStyle(Color.quiet)
            default:
                if quote.isEmpty {
                    words(note.isPartial ? "No words were heard in the part that arrived." : "No words were heard in this recording.", spoken: false)
                } else {
                    words("“\(quote)”", spoken: true)
                }
                outcome
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func words(_ text: String, spoken: Bool) -> some View {
        Text(text).typo(.quote).italic(!spoken).foregroundStyle(spoken ? Color.ink : Color.quiet)
            .lineLimit(4)
            .padding(.top, 4.6)
            .padding(.bottom, 7.6)
    }

    /// The words that asked for the first message or task if there is one, otherwise how the note begins.
    private var quote: String {
        let source = note.messages.first?.draft.source ?? note.tasks.first?.draft.source ?? ""
        return (source.isEmpty ? note.transcript : source).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @ViewBuilder private var outcome: some View {
        switch note.outcome {
        case .messageSent:
            ForEach(Array(note.messages.enumerated()), id: \.offset) { _, message in
                if message.isSent {
                    Text("✓ Sent to \(message.recipientName ?? message.draft.recipient)").typo(.uiStrong).foregroundStyle(Color.brand)
                    Text("“\(message.draft.text)”").typo(.ui).foregroundStyle(Color.quiet)
                }
            }
            ForEach(Array(note.tasks.prefix(2).enumerated()), id: \.offset) { _, task in
                Text("✓ Added · \(task.draft.title)").typo(.uiStrong).foregroundStyle(Color.brand)
            }
        case .asking:
            if let message = note.messages.first(where: { !$0.isSent && $0.recipientNumber == nil }) {
                Text(message.candidates.isEmpty ? "Who is \(message.draft.recipient)?" : "Which \(message.draft.recipient)?").typo(.uiStrong)
                Text("Say the name into the recorder.").typo(.ui).foregroundStyle(Color.quiet)
            }
        case .taskAdded:
            // One line per task, three at most, so a long list does not push the next note off the screen.
            ForEach(Array(note.tasks.prefix(3).enumerated()), id: \.offset) { _, task in
                Text("✓ Added · \(task.draft.title)").typo(.uiStrong).foregroundStyle(Color.brand)
                if !AppModel.details(of: task.draft).isEmpty {
                    Text(AppModel.details(of: task.draft).joined(separator: " · ")).typo(.ui).foregroundStyle(Color.quiet)
                }
            }
            if note.tasks.count > 3 {
                Text("and \(note.tasks.count - 3) more").typo(.ui).foregroundStyle(Color.quiet)
            }
        case .processingFailed:
            Text("Not added yet").typo(.uiStrong)
            Text("Your note is safe.").typo(.ui).foregroundStyle(Color.quiet)
        case .pending:
            Text("Reading…").typo(.ui).foregroundStyle(Color.quiet)
        case .note where note.answer != nil:
            Text(note.answer ?? "").typo(.ui).foregroundStyle(Color.quiet)
        case .note where note.isPartial:
            Text(note.shortfall ?? "").typo(.uiStrong)
            Text("Your whole note is safe on the recorder.").typo(.ui).foregroundStyle(Color.quiet)
        default:
            if let message = note.messages.first {
                Text("Message found, not sent: to \(message.recipientName ?? message.draft.recipient)").typo(.ui).foregroundStyle(Color.quiet)
            } else if let task = note.tasks.first {
                Text(note.tasks.count == 1 ? "Task found, not sent: \(task.draft.title)" : "\(note.tasks.count) tasks found, not sent")
                    .typo(.ui).foregroundStyle(Color.quiet)
            } else {
                Text("Kept as a note").typo(.ui).foregroundStyle(Color.quiet)
            }
        }
    }
}

/// Live capture, over the log: the state, the waveform, and afterwards the transcript and what was done.
struct LiveSheet: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                switch model.phase {
                case .recording:
                    Circle().fill(Color(red: 0.90, green: 0.28, blue: 0.30)).frame(width: 12, height: 12)
                    Text("Recording").typo(.uiStrong)
                    Spacer()
                    if let start = model.recordingStart {
                        Text(start, style: .timer).typo(.ui).monospacedDigit().foregroundStyle(Color.quiet)
                    }
                case .transcribing:
                    ProgressView().controlSize(.small)
                    Text("Transcribing").typo(.uiStrong)
                    Spacer()
                default:
                    Text("Transcript").typo(.uiStrong)
                    Spacer()
                }
            }
            if model.phase == .recording {
                WaveformView(levels: model.levels, color: .brand, barWidth: 5.3, step: 9.1)
                    .frame(height: 91)
                // What has been heard so far; the newest words stay in view.
                ScrollView {
                    (Text(model.liveText) + Text(model.liveTentative).foregroundStyle(Color.quiet))
                        .typo(.live)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .defaultScrollAnchor(.top, for: .alignment)
                .defaultScrollAnchor(.bottom, for: .sizeChanges)
                .padding(.top, 11.4)
            } else {
                ScrollView {
                    Text(model.transcript).typo(.live).frame(maxWidth: .infinity, alignment: .leading)
                    if !model.taskNote.isEmpty {
                        Text(model.taskNote).typo(.uiStrong).foregroundStyle(Color.brand).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.top, 11.4)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(Color.ink)
        .padding(.horizontal, Metric.margin)
        .padding(.top, 40)
        .presentationDetents([.fraction(0.563), .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.sheetPaper)
    }
}

/// The recorder at a glance, in a chip at the top of the log: a dot for its state, a few words,
/// and its battery drawn as one when it is nearby.
struct RecorderBadge: View {
    let connection: RecorderClient.State
    let battery: Int?

    var body: some View {
        HStack(spacing: 7.6) {
            dot.frame(width: 7.6, height: 7.6)
            Text(words).typo(.small).foregroundStyle(connection == .ready ? Color.ink : Color.quiet)
            if connection == .ready, let battery {
                BatteryGlyph(level: battery).padding(.leading, 1.5)
                Text("\(battery)%").typo(.small).foregroundStyle(Color.quiet)
            }
        }
        .padding(.leading, 13.7).padding(.trailing, 15.2).padding(.vertical, 4.6)
        .background(Color.chip, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(battery.map { connection == .ready ? "\(words), battery \($0) percent" : words } ?? words)
    }

    /// Filled in ink when the recorder is there, hollow while it is being looked for, quiet otherwise.
    @ViewBuilder private var dot: some View {
        switch connection {
        case .ready: Circle().fill(Color.ink)
        case .searching, .connecting: Circle().strokeBorder(Color.quiet, lineWidth: 1.5)
        default: Circle().fill(Color.quiet)
        }
    }

    private var words: String {
        switch connection {
        case .ready: return "Recorder nearby"
        case .bluetoothOff: return "Bluetooth is off"
        default: return "Recorder out of reach"
        }
    }
}

/// A small battery, filled to its level.
struct BatteryGlyph: View {
    let level: Int

    var body: some View {
        HStack(spacing: 1.2) {
            RoundedRectangle(cornerRadius: 2.6).strokeBorder(Color.quiet, lineWidth: 1)
                .frame(width: 20.5, height: 10.6)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.2).fill(Color.ink)
                        .frame(width: max(1.5, 16.5 * CGFloat(min(max(level, 0), 100)) / 100), height: 6.6)
                        .padding(.leading, 2)
                }
            RoundedRectangle(cornerRadius: 0.8).fill(Color.quiet).frame(width: 1.6, height: 4.2)
        }
    }
}
