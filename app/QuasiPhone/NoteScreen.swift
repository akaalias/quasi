import SwiftUI

/// One note: what was heard, what was decided and what was done, with the way back.
struct NoteScreen: View {
    let id: String
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var working = false

    private var note: NoteRecord? { model.notes.first { $0.id == id } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button { dismiss() } label: { Text("‹ \(backTitle)").typo(.ui).foregroundStyle(Color.brand) }
                    Spacer()
                    if let transcript = note?.transcript, !transcript.isEmpty {
                        ShareLink(item: transcript) {
                            Image(systemName: "ellipsis").font(.system(size: 17, weight: .semibold)).foregroundStyle(Color.quiet)
                        }
                    }
                }
                if let note {
                    Text(heading(for: note)).typo(.ui).foregroundStyle(Color.quiet).padding(.top, Metric.gap)
                    if !note.transcript.isEmpty {
                        Text(marked(note)).typo(.transcript).textSelection(.enabled)
                            .padding(.top, 11.4).padding(.bottom, 22.8)
                    }
                    ForEach(Array(note.tasks.enumerated()), id: \.offset) { index, task in
                        card(for: task.draft, added: task.todoistID != nil).padding(.bottom, Metric.gap)
                        // With several tasks, each has its own way back; a single one uses the note's.
                        if note.tasks.count > 1 {
                            act(task.todoistID != nil ? "Undo this one" : "Drop this one") { await model.undoTask(id, index: index) }
                                .padding(.bottom, Metric.gap)
                        }
                    }
                    if let problem = note.problem {
                        Text(problem).typo(.ui)
                        Text("Your note is safe.").typo(.ui).foregroundStyle(Color.quiet).padding(.bottom, Metric.gap)
                    }
                    actions(for: note)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Metric.margin)
            .padding(.top, 2.7)
            .padding(.bottom, 40)
        }
        .foregroundStyle(Color.ink)
        .background(Color.paper)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var backTitle: String {
        guard let date = note?.date else { return "Notes" }
        return Calendar.current.isDateInToday(date) ? "Today" : Calendar.current.isDateInYesterday(date) ? "Yesterday" : "Notes"
    }

    private func heading(for note: NoteRecord) -> String {
        let moment = note.date.formatted(.dateTime.weekday(.wide)) + " " + note.date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
        guard let seconds = note.seconds else { return moment }
        return moment + " · " + (seconds < 90 ? "\(seconds) seconds" : "\(seconds / 60) minutes")
    }

    /// The transcript with the words that asked for each task marked, so the reasons are visible.
    private func marked(_ note: NoteRecord) -> AttributedString {
        var text = AttributedString(note.transcript)
        for source in note.tasks.map(\.draft.source) where !source.isEmpty {
            if let range = text.range(of: source) {
                text[range].backgroundColor = .mark
            }
        }
        return text
    }

    private func card(for task: TaskDraft, added: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(added ? "✓ Added to Todoist" : "Task found").typo(.uiStrong).foregroundStyle(Color.brand).padding(.bottom, 7.6)
            Text(task.title).typo(.cardTitle)
            Rule().padding(.vertical, Metric.gap)
            field("Due", Self.day(task.dueDate, time: task.dueTime) ?? (task.due.isEmpty ? "None said" : "“\(task.due)”"))
            if !task.recurrence.isEmpty { field("Repeats", task.recurrence) }
            if let deadline = Self.day(task.deadlineDate, time: "") { field("Deadline", deadline) }
            field("Project", task.project.isEmpty ? "Inbox" : task.section.isEmpty ? task.project : "\(task.project) / \(task.section)")
            field("Priority", task.priority > 0 ? "p\(task.priority)" : "None said")
            if task.durationMinutes > 0 { field("Takes", "\(task.durationMinutes) min") }
            if !task.labels.isEmpty { field("Labels", task.labels.joined(separator: ", ")) }
        }
        .padding(.horizontal, 19.8)
        .padding(.vertical, 18.3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.card, in: RoundedRectangle(cornerRadius: Metric.radius))
    }

    private func field(_ name: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(name).foregroundStyle(Color.quiet)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
        .typo(.ui)
    }

    /// "2026-10-08" as "Thu 8 Oct", with the time if there is one.
    private static func day(_ iso: String, time: String) -> String? {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: iso) else { return nil }
        let day = date.formatted(.dateTime.weekday(.abbreviated)) + " " + date.formatted(.dateTime.day()) + " " + date.formatted(.dateTime.month(.abbreviated))
        return time.isEmpty ? day : "\(day), \(time)"
    }

    @ViewBuilder private func actions(for note: NoteRecord) -> some View {
        HStack(spacing: 7.6) {
            switch note.outcome {
            case .taskAdded:
                act(note.tasks.count == 1 ? "Undo" : "Undo all") { await model.undoTask(id) }
            case .processingFailed:
                act("Try again") { await model.process(id) }
            case .noAudio, .transcriptionFailed:
                act("Fetch from the recorder") { model.requestSync() }
                    .disabled(model.connection != .ready)
            case .note where model.hasAnthropicKey && !note.transcript.isEmpty:
                act("Make this into tasks") { await model.process(id, confirmed: true) }
            default:
                EmptyView()
            }
            if working { ProgressView().padding(.leading, 8) }
        }
    }

    private func act(_ title: String, _ action: @escaping () async -> Void) -> some View {
        Button(title) {
            working = true
            Task {
                await action()
                working = false
            }
        }
        .buttonStyle(PillStyle())
        .disabled(working)
    }
}
