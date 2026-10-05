import Foundation

enum TodoistError: LocalizedError {
    case api(String)

    var errorDescription: String? {
        switch self {
        case .api(let message): return message
        }
    }
}

/// Adds tasks to the user's Todoist. It reads the names of projects, sections and labels, so a
/// task can be filed where the speaker said. It never reads or changes tasks, and the only task
/// it can delete is one it added itself, when the user undoes it.
enum TodoistClient {
    private static let base = "https://api.todoist.com/api/v1/"

    /// Where tasks can go: names for the model, and the ids those names stand for.
    struct Directory {
        var catalog = TaskCatalog()
        var projectIDs: [String: String] = [:]
        /// Keyed by project name, then section name.
        var sectionIDs: [String: [String: String]] = [:]
    }

    static func directory(token: String) async throws -> Directory {
        async let projects = list("projects", token: token)
        async let sections = list("sections", token: token)
        async let labels = list("labels", token: token)
        var directory = Directory()
        var projectNames: [String: String] = [:]
        for project in try await projects {
            guard let id = project["id"] as? String, let name = project["name"] as? String else { continue }
            projectNames[id] = name
            directory.projectIDs[name] = id
            directory.catalog.projects.append(.init(name: name))
        }
        for section in try await sections {
            guard let id = section["id"] as? String, let name = section["name"] as? String,
                  let project = (section["project_id"] as? String).flatMap({ projectNames[$0] }),
                  let index = directory.catalog.projects.firstIndex(where: { $0.name == project }) else { continue }
            directory.catalog.projects[index].sections.append(name)
            directory.sectionIDs[project, default: [:]][name] = id
        }
        directory.catalog.labels = try await labels.compactMap { $0["name"] as? String }
        return directory
    }

    /// Adds the task and returns its Todoist id. The transcript goes into the description, so
    /// nothing the speaker said is lost if a field came out wrong.
    static func add(_ draft: TaskDraft, in directory: Directory = Directory(), transcript: String, recordedAt: Date,
                    token: String) async throws -> String {
        var description: [String] = []
        if !draft.notes.isEmpty { description.append(draft.notes) }
        if !draft.due.isEmpty, draft.dueDate.isEmpty, draft.recurrence.isEmpty { description.append("Due, as said: \(draft.due)") }
        let voiceNote = "Voice note, \(recordedAt.formatted(date: .abbreviated, time: .shortened)):\n\(transcript)"

        var body: [String: Any] = ["content": draft.title]
        if draft.priority > 0 { body["priority"] = 5 - draft.priority }       // the API counts the other way: 4 is p1
        if !draft.labels.isEmpty { body["labels"] = draft.labels }
        if let project = directory.projectIDs[draft.project] {
            body["project_id"] = project
            if let section = directory.sectionIDs[draft.project]?[draft.section] { body["section_id"] = section }
        }
        var timing: [String: Any] = [:]
        if !draft.recurrence.isEmpty {
            // Todoist parses repeats from a phrase; the time and first day ride along in it.
            var phrase = draft.recurrence
            if !draft.dueTime.isEmpty { phrase += " at \(draft.dueTime)" }
            if !draft.dueDate.isEmpty { phrase += " starting \(draft.dueDate)" }
            timing["due_string"] = phrase
            timing["due_lang"] = "en"
        } else if !draft.dueDate.isEmpty {
            if draft.dueTime.isEmpty {
                timing["due_date"] = draft.dueDate
            } else {
                timing["due_datetime"] = "\(draft.dueDate)T\(draft.dueTime):00"     // no zone: the user's local time
            }
        }
        if !draft.deadlineDate.isEmpty { timing["deadline_date"] = draft.deadlineDate }
        if draft.durationMinutes > 0, !draft.dueTime.isEmpty {
            timing["duration"] = draft.durationMinutes
            timing["duration_unit"] = "minute"
        }

        do {
            body["description"] = (description + [voiceNote]).joined(separator: "\n\n")
            return try await create(body.merging(timing) { $1 }, token: token)
        } catch TodoistError.api(let message) where !timing.isEmpty {
            // Todoist rejects timing it cannot parse. Keep the task: add it without, and say so in it.
            let said = [draft.due, draft.recurrence, draft.deadlineDate.isEmpty ? "" : "deadline \(draft.deadlineDate)"]
                .filter { !$0.isEmpty }.joined(separator: ", ")
            body["description"] = (description + ["Todoist did not accept the timing (\(message)): \(said)", voiceNote])
                .joined(separator: "\n\n")
            return try await create(body, token: token)
        }
    }

    /// Removes a task this app added. A task that is already gone counts as removed.
    static func remove(taskID: String, token: String) async throws {
        var request = URLRequest(url: URL(string: base + "tasks/" + taskID)!)
        request.httpMethod = "DELETE"
        request.timeoutInterval = 30
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 204 || status == 404 else {
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
            throw TodoistError.api(json["error"] as? String ?? "Todoist did not remove the task.")
        }
    }

    private static func create(_ body: [String: Any], token: String) async throws -> String {
        var request = URLRequest(url: URL(string: base + "tasks")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        guard (response as? HTTPURLResponse)?.statusCode == 200, let id = json["id"] as? String else {
            throw TodoistError.api(json["error"] as? String ?? "Todoist did not accept the task.")
        }
        return id
    }

    /// Every item of a paged listing such as `projects`.
    private static func list(_ path: String, token: String) async throws -> [[String: Any]] {
        var items: [[String: Any]] = []
        var cursor: String?
        repeat {
            var components = URLComponents(string: base + path)!
            components.queryItems = [URLQueryItem(name: "limit", value: "200")] + (cursor.map { [URLQueryItem(name: "cursor", value: $0)] } ?? [])
            var request = URLRequest(url: components.url!)
            request.timeoutInterval = 20
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (data, response) = try await URLSession.shared.data(for: request)
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw TodoistError.api(json["error"] as? String ?? "Todoist did not answer.")
            }
            items += json["results"] as? [[String: Any]] ?? []
            cursor = json["next_cursor"] as? String
        } while cursor != nil
        return items
    }
}
