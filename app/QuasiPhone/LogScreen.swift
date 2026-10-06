import SwiftUI

/// Home: every recording, newest first, each as the speaker's own words and one line saying
/// what became of them. Live capture rises over it as a sheet; settings sit behind one button.
struct LogScreen: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingSettings = UserDefaults.standard.string(forKey: "demo") == "settings"
    @State private var liveDismissed = false
    @State private var path: [String] = []

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text(status).typo(.ui).foregroundStyle(Color.quiet)
                        Spacer()
                        Button { showingSettings = true } label: {
                            Image(systemName: "gearshape").font(.system(size: 15)).foregroundStyle(Color.quiet)
                        }
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

    private var status: String {
        switch model.connection {
        case .ready: return model.battery.map { "Recorder nearby · \($0)%" } ?? "Recorder nearby"
        case .bluetoothOff: return "Bluetooth is off"
        default: return "Recorder out of reach"
        }
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

    /// The words that asked for the first task if there is one, otherwise how the note begins.
    private var quote: String {
        let source = note.tasks.first?.draft.source ?? ""
        return (source.isEmpty ? note.transcript : source).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @ViewBuilder private var outcome: some View {
        switch note.outcome {
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
        case .note where note.isPartial:
            Text(note.shortfall ?? "").typo(.uiStrong)
            Text("Your whole note is safe on the recorder.").typo(.ui).foregroundStyle(Color.quiet)
        default:
            if let task = note.tasks.first {
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
