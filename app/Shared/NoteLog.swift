import Foundation

/// One recording in the log: what was heard and what became of it.
struct NoteRecord: Codable, Identifiable, Equatable {
    enum Outcome: String, Codable {
        /// Transcribed; what to do with it is not decided yet.
        case pending
        /// Nothing was asked for, or nothing is set up to act on it.
        case note
        case taskAdded
        /// A message the note asked for was sent on its way (and any tasks were added).
        case messageSent
        /// The app has a question about this note and waits for the next recording to answer it.
        case asking
        /// The recording was made, but its audio did not reach this device. It is still on the recorder.
        case noAudio
        case transcriptionFailed
        /// Reading the note or adding the task failed. The transcript is saved.
        case processingFailed
    }

    /// The base name of the note's files, e.g. "2026-10-05 14.03.12".
    var id: String
    var date: Date
    /// How much audio this device has of the recording, in seconds, if known.
    var seconds: Int?
    /// How long the recorder itself recorded, in seconds, if known.
    var recorded: Int?
    var transcript = ""
    var outcome = Outcome.pending
    /// The tasks this note asked for, in the order they were asked.
    var tasks: [AddedTask] = []
    /// The messages this note asked to have sent, in the order they were asked.
    var messages: [SentMessage] = []
    /// What went wrong, for the two failed outcomes.
    var problem: String?
    /// For a note that answered a question the app asked: what the answer was taken to be.
    var answer: String?
}

/// A message found in a note, and whether it went.
struct SentMessage: Codable, Equatable {
    var draft: MessageDraft
    /// The person it was sent to, once known: a name from Contacts and the number used.
    var recipientName: String?
    var recipientNumber: String?
    /// The people the spoken name could mean, while that is still an open question.
    var candidates: [Candidate] = []
    /// The id of the relay message once it has been handed to the phone's own messaging.
    var relayID: String?

    var isSent: Bool { relayID != nil }
}

/// One person a spoken name could mean.
struct Candidate: Codable, Equatable, Identifiable {
    var name: String
    var number: String
    /// What tells this person apart from a namesake: a company, a nickname, the number's label.
    var detail = ""

    var id: String { number }
}

/// A task found in a note, and where it went.
struct AddedTask: Codable, Equatable {
    var draft: TaskDraft
    /// The id of the task in Todoist once it has been added there, so it can be removed again.
    var todoistID: String?
}

extension NoteRecord {
    /// Logs written when a note could hold one task only kept it as `task` and `todoistID`.
    private enum Earlier: String, CodingKey {
        case task, todoistID
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        date = try values.decode(Date.self, forKey: .date)
        seconds = try values.decodeIfPresent(Int.self, forKey: .seconds)
        recorded = try values.decodeIfPresent(Int.self, forKey: .recorded)
        transcript = try values.decodeIfPresent(String.self, forKey: .transcript) ?? ""
        outcome = try values.decodeIfPresent(Outcome.self, forKey: .outcome) ?? .pending
        problem = try values.decodeIfPresent(String.self, forKey: .problem)
        answer = try values.decodeIfPresent(String.self, forKey: .answer)
        messages = try values.decodeIfPresent([SentMessage].self, forKey: .messages) ?? []
        if let tasks = try values.decodeIfPresent([AddedTask].self, forKey: .tasks) {
            self.tasks = tasks
        } else {
            let earlier = try decoder.container(keyedBy: Earlier.self)
            if let draft = try earlier.decodeIfPresent(TaskDraft.self, forKey: .task) {
                tasks = [AddedTask(draft: draft, todoistID: try earlier.decodeIfPresent(String.self, forKey: .todoistID))]
            }
        }
    }
}

extension NoteRecord {
    /// The live stream always loses a little. Missing more than this much, the words cannot be trusted.
    static func isPartial(kept: Int, recorded: Int) -> Bool {
        recorded - kept > max(2, recorded / 5)
    }

    /// Whether a good part of the recording never reached this device. The recorder has all of it.
    var isPartial: Bool {
        guard let seconds, let recorded else { return false }
        return Self.isPartial(kept: seconds, recorded: recorded)
    }

    /// Says how much is missing, for a note that is partial.
    var shortfall: String? {
        guard isPartial, let seconds, let recorded else { return nil }
        return "Only \(seconds) of \(recorded) seconds of this recording arrived."
    }
}

/// The log on disk: `log.json` in the recordings folder, newest first.
enum NoteLog {
    private static func file(in folder: URL) -> URL { folder.appendingPathComponent("log.json") }

    /// The saved log, or nil while its files are there but cannot be read: after the phone
    /// restarts, the app can be woken by the recorder before the phone is first unlocked, and
    /// until then iOS keeps the files closed. A log read then would come out empty, and saved,
    /// would replace the real one, so the caller must wait and try again.
    static func load(from folder: URL) -> [NoteRecord]? {
        let manager = FileManager.default
        let log = file(in: folder)
        if manager.fileExists(atPath: log.path) {
            guard let data = try? Data(contentsOf: log) else { return nil }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let notes = try? decoder.decode([NoteRecord].self, from: data) {
                return restoringTranscripts(notes, from: folder)
            }
            // Readable but not understood: kept aside rather than written over.
            let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: ".")
            try? manager.moveItem(at: log, to: folder.appendingPathComponent("log unreadable \(stamp).json"))
        }
        // Before there was a log: every saved transcript becomes a plain note.
        let names = DateFormatter()
        names.locale = Locale(identifier: "en_US_POSIX")
        names.dateFormat = "yyyy-MM-dd HH.mm.ss"
        let files = (try? manager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        var notes: [NoteRecord] = []
        for url in files where url.pathExtension == "txt" {
            let name = url.deletingPathExtension().lastPathComponent
            guard let date = names.date(from: name) else { continue }
            guard let transcript = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            notes.append(NoteRecord(id: name, date: date, transcript: transcript, outcome: .note))
        }
        return notes.sorted { $0.date > $1.date }
    }

    /// A note whose words are missing from the log but are in its `.txt` file gets them back.
    /// On 22 October 2026 a log rebuilt while the phone was locked replaced every transcript
    /// with nothing; the files kept them.
    private static func restoringTranscripts(_ notes: [NoteRecord], from folder: URL) -> [NoteRecord] {
        notes.map { note in
            guard note.transcript.isEmpty, note.outcome == .note,
                  let text = try? String(contentsOf: folder.appendingPathComponent(note.id + ".txt"), encoding: .utf8),
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return note }
            var restored = note
            restored.transcript = text
            return restored
        }
    }

    static func save(_ notes: [NoteRecord], to folder: URL) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try? encoder.encode(notes).write(to: file(in: folder), options: .atomic)
    }
}
