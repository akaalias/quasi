import Foundation

/// The app asked which person a message is for, and the speaker has answered with another
/// recording. This reads the answer, using Claude.
enum Clarifier {
    enum Reply: Equatable {
        /// The answer picks one of the candidates (an index into the list given).
        case chosen(Int)
        /// The speaker named someone not in the list, by a name to look up again.
        case someoneElse(String)
        /// The speaker does not want the message sent after all.
        case cancelled
        /// The recording is about something else; the question stays unanswered.
        case unrelated
    }

    private static let instructions = """
    A voice assistant asked its owner a question out loud and the owner answered by recording a \
    short voice note. You read the transcript of that note and say what the answer is. The \
    question was which of several people a message should go to; the people are numbered. The \
    transcript comes from speech recognition, so expect filler and misheard words, and the \
    answer can be in any language.

    Answer with exactly one of:
    - chosen: the number of the person the owner picked, if they named one of them (by first \
    name, surname, nickname, company, or "the first one"), or if only one person fits what they said;
    - someone_else: the name of a person they named who is not in the list, exactly as they said it;
    - cancelled: they said not to send it, to forget it, or to drop it;
    - unrelated: the note does not answer the question at all; it is about something else.
    Fill `chosen` with 0 and `name` with an empty string when they do not apply.
    """

    private static let schema: [String: Any] = [
        "type": "object",
        "properties": [
            "answer": ["type": "string", "enum": ["chosen", "someone_else", "cancelled", "unrelated"]],
            "chosen": ["type": "integer"],
            "name": ["type": "string"],
        ],
        "required": ["answer", "chosen", "name"],
        "additionalProperties": false,
    ]

    private static let matchInstructions = """
    A voice assistant was asked to send a message to a person named in a voice note, and has to \
    work out who in its owner's contacts is meant. You get the name as heard by speech \
    recognition, the sentence it came from, and the contacts, numbered. Speech recognition spells \
    names as it pleases ("Franciska" for Franziska), and people use nicknames and short forms \
    ("Toby" for Tobias, "Franzi", "Mum") or a detail ("Alex from the gym"). Use everything the \
    sentence gives away: the pronoun used for the person, a company, a relationship. A name that \
    only begins like the one heard is a weak match: "Franciska" is not Franz. Give every contact \
    that plausibly fits, most likely first, and an empty list if none does. Do not pick someone \
    just because they are the only contact.

    """

    private static let matchSchema: [String: Any] = [
        "type": "object",
        "properties": ["matches": ["type": "array", "items": ["type": "integer"]]],
        "required": ["matches"],
        "additionalProperties": false,
    ]

    /// At most this many contacts are offered to the model; with more, only exact matches count.
    static let mostContacts = 300

    /// The contacts the name heard could mean, by the model's judgement, most likely first.
    static func match(_ heard: String, in sentence: String, among people: [Candidate], apiKey: String) async throws -> [Candidate] {
        guard !people.isEmpty, people.count <= mostContacts else { return [] }
        let list = people.enumerated().map { index, person in
            "\(index + 1). \(person.name)" + (person.detail.isEmpty ? "" : " (\(person.detail))")
        }
        let message = "Name as heard: \(heard)\n\nThe sentence: \(sentence)\n\nContacts:\n" + list.joined(separator: "\n")
        let answer = try await ask(system: matchInstructions, user: message, schema: matchSchema, maxTokens: 300, apiKey: apiKey)
        let indices = (answer["matches"] as? [Int] ?? []).map { $0 - 1 }.filter { people.indices.contains($0) }
        var seen: Set<Int> = []
        return indices.filter { seen.insert($0).inserted }.map { people[$0] }
    }

    static func read(answer transcript: String, question: String, candidates: [Candidate], apiKey: String) async throws -> Reply {
        let people = candidates.enumerated().map { index, person in
            "\(index + 1). \(person.name)" + (person.detail.isEmpty ? "" : " (\(person.detail))")
        }
        let message = "The question asked: \(question)\n\nThe people:\n" + (people.isEmpty ? "(nobody of that name was found)" : people.joined(separator: "\n"))
            + "\n\nTranscript of the owner's answer:\n\n\(transcript)"
        let answer = try await ask(system: instructions, user: message, schema: schema, maxTokens: 200, apiKey: apiKey)
        switch answer["answer"] as? String {
        case "chosen":
            let index = (answer["chosen"] as? Int ?? 0) - 1
            return candidates.indices.contains(index) ? .chosen(index) : .unrelated
        case "someone_else":
            let name = (answer["name"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? .unrelated : .someoneElse(name)
        case "cancelled": return .cancelled
        default: return .unrelated
        }
    }

    /// One quick question to Claude, answered in the shape of the schema.
    private static func ask(system: String, user: String, schema: [String: Any], maxTokens: Int, apiKey: String) async throws -> [String: Any] {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        let body: [String: Any] = [
            "model": TaskExtractor.model,
            "max_tokens": maxTokens,
            "system": system,
            "messages": [["role": "user", "content": user]],
            "output_config": ["effort": "low", "format": ["type": "json_schema", "schema": schema]],
            "fallbacks": "default",
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw TaskExtractorError.api((json["error"] as? [String: Any])?["message"] as? String ?? "The request to Claude failed.")
        }
        let blocks = json["content"] as? [[String: Any]] ?? []
        guard let text = blocks.first(where: { $0["type"] as? String == "text" })?["text"] as? String,
              let answer = (try? JSONSerialization.jsonObject(with: Data(text.utf8))) as? [String: Any] else {
            throw TaskExtractorError.unreadable
        }
        return answer
    }
}
