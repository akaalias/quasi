import Foundation

/// One task the speaker asked for in a voice note, with everything they said about it.
/// A note can ask for none, one or several.
struct TaskDraft: Codable, Equatable {
    var title: String
    /// Details someone doing the task would want. Empty if none.
    var notes = ""
    /// The speaker's words that ask for the task, as they stand in the transcript.
    var source = ""
    /// When to do it, in the speaker's words. Empty if no time was given.
    var due = ""
    /// The day to do it as `yyyy-MM-dd`, counted from the recording. Empty if none or too vague.
    var dueDate = ""
    /// The clock time to do it as `HH:mm`. Empty unless the speaker named one.
    var dueTime = ""
    /// How it repeats, as a phrase Todoist understands ("every monday"). Empty if it does not repeat.
    var recurrence = ""
    /// A hard deadline, as distinct from the day to do it, as `yyyy-MM-dd`. Empty if none.
    var deadlineDate = ""
    /// 1 (most urgent) to 4, as in Todoist's p1 to p4. 0 if the speaker gave no priority.
    var priority = 0
    /// How long it will take. 0 if not said.
    var durationMinutes = 0
    /// Names from the user's Todoist, exactly as listed there. Empty if the speaker named none.
    var project = ""
    var section = ""
    var labels: [String] = []
}

/// The projects, sections and labels a task can be filed under, by name.
struct TaskCatalog: Codable, Equatable {
    struct Project: Codable, Equatable {
        var name: String
        var sections: [String] = []
    }

    var projects: [Project] = []
    var labels: [String] = []
}

enum TaskExtractorError: LocalizedError {
    case api(String)
    case declined
    case unreadable

    var errorDescription: String? {
        switch self {
        case .api(let message): return message
        case .declined: return "The model declined to read this note."
        case .unreadable: return "The model's answer could not be read."
        }
    }
}

/// Finds the tasks a transcript asks for and writes them down, using Claude.
/// The transcript text and the names in the catalog are sent to Anthropic's API.
enum TaskExtractor {
    static let model = "claude-sonnet-5-5"

    static let instructions = """
    You read transcripts of voice notes that one person records for themselves on a pocket \
    recorder. The text comes from speech recognition, so expect filler words, false starts and \
    the occasional misheard word.

    Most notes are thinking aloud, or tests of the recorder, and contain no task. Find every task \
    the speaker asks to have added to their to-do list. A request can come anywhere: at the \
    start ("add a new task, ..."), or in the middle or at the end of a ramble ("oh, add that as a \
    task", "this reminds me, we need to add a task for ...", "remind me to ...", "put that on my \
    to-do list"). Notes can be in any language.

    Talking about tasks, plans or a to-do list is not a request. Neither is mentioning something \
    the speaker intends to do, unless they ask for it to be recorded as a task, to-do or reminder.

    Naming things as tasks or to-dos is asking for them, even without the word "add": "a few \
    tasks for tomorrow, which is, I need to wash the car and buy groceries", "my to-dos for \
    today: ...", "one to-do for Thursday, ...". Each thing named is a task. A plain "I need to \
    ...", "the plan is ..." or "tomorrow is busy, I have to ..." names no task and stays a note.

    A direct request ("add a task", "new task", "remind me to", "put that on my list" and the \
    like) always counts, however short or plain the note is. Only when there is no such request \
    and you are unsure whether the speaker wants something recorded is the answer no task.

    Answer with a list: one entry per task, in the order the speaker asked for them, and an empty \
    list if they asked for none. What makes something its own task is that the speaker asked for \
    it separately, or listed it as one of several:
    - Two requests are two tasks ("add a task, call the plumber, and another one, buy light bulbs").
    - A list the speaker dictates is one task per item ("three tasks: buy stamps, post the \
    letter, pick up the photos"; "make those two tasks").
    - One request stays one task however much it contains. "Call the dentist and ask about the \
    bill", "go to the hardware store and get screws and wall plugs", "plan the party: invite the \
    class, order the cake" are each a single task; the steps, items and details belong in its \
    title or notes. The speaker would be annoyed to find one errand cut into three to-dos.
    - Something the speaker only intends or mentions, next to a real request, is not a task.
    - If the speaker takes a task back ("scratch the second one", "forget the gym one"), leave it out.
    What the speaker says about several tasks at once applies to each of them ("all for \
    tomorrow", "both in Work", "two urgent tasks").

    For each task, fill in the fields below from what the speaker said. Leave a field empty (or \
    zero) when they said nothing about it; never fill one in from a guess. If the speaker \
    corrects themselves, use the correction.

    - title: the task as a short imperative phrase in the speaker's language. Keep the specifics \
    (who, what, which one) and drop filler. When the request points back ("add that as a task"), \
    work out what "that" is from what they said before. The title carries only the task: no \
    date, priority, project or label words.
    - notes: other details the speaker gave that someone doing the task would want, in a sentence \
    or two.
    - source: the one or two sentences in which the speaker says what this task is and asks for \
    it, copied from the transcript character for character, so they can be found in it again. \
    For one item of a dictated list, copy just the words of that item.
    - due: when to do the task, in the speaker's own words ("tomorrow morning", "by Friday").
    - due_date: the day meant by `due`, as YYYY-MM-DD, counted from the recording date given with \
    the transcript. "By Friday" is that Friday; "a few days before the twentieth" is about three \
    days before; "next week" with no day is the Monday of next week; "this weekend" is the \
    Saturday. If the speaker names a clock time but no day, it is the recording day, or the next \
    day if that time has already passed. A date that is part of the task itself, such as the day \
    an appointment should be moved to, is not a due date. For a repeating task, give the first \
    day it falls on, on or after the recording day.
    - due_time: the clock time to do it, as 24-hour HH:MM, only if the speaker named one ("at \
    three", "at half past nine", "um 15 Uhr"). "Morning", "afternoon" and "evening" are not \
    clock times. With no other clue, a bare hour from one to seven means the afternoon.
    - recurrence: if the task repeats, how, as a lowercase English phrase of exactly one of these \
    shapes: "every day", "every weekday", "every monday" (any weekday name), "every 2 weeks" \
    (any number of days, weeks, months or years), "every month on the 15th", "every year on \
    october 20", "every monday and thursday". Put the clock time in due_time, not here.
    - deadline_date: only if the speaker uses the word deadline (or its equivalent, such as \
    "Frist") for a date, as YYYY-MM-DD. This is the last possible day, as distinct from the day \
    they plan to do it; a note can have both. A plain "by Friday" is a due date, not a deadline.
    - priority: 1 if they call it urgent, critical, top or highest priority, or "priority one" / \
    "p1"; 2 for high priority, important, or "p2"; 3 for medium priority or "p3"; 4 for low \
    priority, "no rush", "whenever", or "p4"; 0 if they said nothing about priority.
    - duration_minutes: how long they say it will take or should be blocked for, in minutes.
    - project, section: only if the speaker says where it goes ("in my Work project", "under \
    Admin", "put it in Home"). Use the exact name from the list given with the transcript; the \
    speech recognition may have garbled it. If they name a section, also give its project. If \
    what they name matches nothing in the list, leave both empty and mention it in notes. Do not \
    choose a project from the topic alone.
    - labels: only labels the speaker asks for ("label it errands", "tag that as waiting"), as \
    exact names from the list. Leave out any that match nothing in the list.
    """

    private static let schema: [String: Any] = [
        "type": "object",
        "properties": ["tasks": ["type": "array", "items": taskSchema]],
        "required": ["tasks"],
        "additionalProperties": false,
    ]

    private static let taskSchema: [String: Any] = [
        "type": "object",
        "properties": [
            "title": ["type": "string"],
            "notes": ["type": "string"],
            "source": ["type": "string"],
            "due": ["type": "string"],
            "due_date": ["type": "string"],
            "due_time": ["type": "string"],
            "recurrence": ["type": "string"],
            "deadline_date": ["type": "string"],
            "priority": ["type": "integer"],
            "duration_minutes": ["type": "integer"],
            "project": ["type": "string"],
            "section": ["type": "string"],
            "labels": ["type": "array", "items": ["type": "string"]],
        ],
        "required": ["title", "notes", "source", "due", "due_date", "due_time", "recurrence", "deadline_date",
                     "priority", "duration_minutes", "project", "section", "labels"],
        "additionalProperties": false,
    ]

    /// One answer from the model, with what it cost.
    struct Extraction {
        var drafts: [TaskDraft]
        var model: String
        var inputTokens: Int
        var outputTokens: Int
    }

    /// Returns the tasks the speaker asked for, in the order they asked; empty if the note asks for none.
    /// `recordedAt` is what "tomorrow" and "Friday" in the note are counted from.
    /// With `confirmed`, the speaker has said afterwards that this note should become a task.
    static func extract(from transcript: String, recordedAt: Date = Date(), catalog: TaskCatalog = TaskCatalog(),
                        confirmed: Bool = false, apiKey: String) async throws -> [TaskDraft] {
        try await extraction(from: transcript, recordedAt: recordedAt, catalog: catalog, confirmed: confirmed, apiKey: apiKey).drafts
    }

    /// The message the model is given for one note: when it was recorded, where tasks can go, and the transcript.
    static func message(transcript: String, recordedAt: Date, catalog: TaskCatalog, confirmed: Bool = false,
                        timeZone: TimeZone = .current) -> String {
        let day = DateFormatter()
        day.locale = Locale(identifier: "en_US_POSIX")
        day.timeZone = timeZone
        day.dateFormat = "EEEE, yyyy-MM-dd 'at' HH:mm"
        var parts = ["Recorded on \(day.string(from: recordedAt))."]
        if !catalog.projects.isEmpty {
            let lines = catalog.projects.map { project in
                project.sections.isEmpty ? "- \(project.name)" : "- \(project.name) (sections: \(project.sections.joined(separator: ", ")))"
            }
            parts.append("Projects:\n" + lines.joined(separator: "\n"))
        }
        if !catalog.labels.isEmpty {
            parts.append("Labels: " + catalog.labels.joined(separator: ", "))
        }
        parts.append("Transcript of the voice note:\n\n\(transcript)")
        if confirmed {
            parts.append("The speaker has looked at this note afterwards and asked for it to be made into tasks. "
                         + "Give one task for each thing in it that they need or mean to do, and at least one: the one it is most "
                         + "plausibly about. For `source`, give the sentence that says what to do.")
        }
        return parts.joined(separator: "\n\n")
    }

    static func extraction(from transcript: String, recordedAt: Date = Date(), catalog: TaskCatalog = TaskCatalog(),
                           confirmed: Bool = false, timeZone: TimeZone = .current, apiKey: String) async throws -> Extraction {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4000,
            "system": instructions,
            "messages": [["role": "user", "content": message(transcript: transcript, recordedAt: recordedAt, catalog: catalog, confirmed: confirmed, timeZone: timeZone)]],
            // Low effort: this is a quick read, and the answer should arrive within a second or two.
            "output_config": ["effort": "low", "format": ["type": "json_schema", "schema": schema]],
            // If a safety classifier declines the request, the API retries it on another model.
            "fallbacks": "default",
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            let message = (json["error"] as? [String: Any])?["message"] as? String
            throw TaskExtractorError.api(message ?? "The request to Claude failed.")
        }
        if json["stop_reason"] as? String == "refusal" { throw TaskExtractorError.declined }
        let blocks = json["content"] as? [[String: Any]] ?? []
        guard json["stop_reason"] as? String == "end_turn",
              let text = blocks.first(where: { $0["type"] as? String == "text" })?["text"] as? String,
              let answer = try? JSONDecoder().decode(Answer.self, from: Data(text.utf8)) else {
            throw TaskExtractorError.unreadable
        }
        let usage = json["usage"] as? [String: Any] ?? [:]
        return Extraction(drafts: answer.tasks.compactMap { $0.draft(in: catalog) }, model: json["model"] as? String ?? "",
                          inputTokens: usage["input_tokens"] as? Int ?? 0, outputTokens: usage["output_tokens"] as? Int ?? 0)
    }

    private struct Answer: Decodable {
        let tasks: [Item]
    }

    private struct Item: Decodable {
        let title: String
        let notes: String
        let source: String
        let due: String
        let due_date: String
        let due_time: String
        let recurrence: String
        let deadline_date: String
        let priority: Int
        let duration_minutes: Int
        let project: String
        let section: String
        let labels: [String]

        /// The entry as a draft, with anything malformed or not in the catalog dropped.
        func draft(in catalog: TaskCatalog) -> TaskDraft? {
            let title = clean(self.title)
            guard !title.isEmpty else { return nil }
            var draft = TaskDraft(title: title)
            draft.notes = clean(notes)
            draft.source = clean(source)
            draft.due = clean(due)
            draft.dueDate = matching(due_date, #"^\d{4}-\d{2}-\d{2}$"#)
            draft.dueTime = matching(due_time, #"^([01]\d|2[0-3]):[0-5]\d$"#)
            let repeats = clean(recurrence).lowercased()
            draft.recurrence = repeats.hasPrefix("every ") ? repeats : ""        // anything else is not a repeat
            draft.deadlineDate = matching(deadline_date, #"^\d{4}-\d{2}-\d{2}$"#)
            draft.priority = (1...4).contains(priority) ? priority : 0
            draft.durationMinutes = max(0, min(duration_minutes, 24 * 60))
            if let project = catalog.projects.first(where: { same($0.name, self.project) }) {
                draft.project = project.name
                draft.section = project.sections.first { same($0, self.section) } ?? ""
            }
            draft.labels = labels.compactMap { wanted in catalog.labels.first { same($0, wanted) } }
            return draft
        }

        private func clean(_ text: String) -> String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
        private func same(_ a: String, _ b: String) -> Bool { clean(a).caseInsensitiveCompare(clean(b)) == .orderedSame }
        private func matching(_ text: String, _ pattern: String) -> String {
            let text = clean(text)
            return text.range(of: pattern, options: .regularExpression) == nil ? "" : text
        }
    }
}
