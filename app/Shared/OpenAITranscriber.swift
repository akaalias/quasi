import Foundation

enum OpenAITranscriberError: LocalizedError {
    case tooLarge
    case api(String)
    case unreadable

    var errorDescription: String? {
        switch self {
        case .tooLarge: return "The recording is larger than OpenAI accepts."
        case .api(let message): return message
        case .unreadable: return "OpenAI's answer could not be read."
        }
    }
}

/// Speech-to-text by OpenAI, for notes that wander between languages. Apple's transcriber
/// (see Transcriber.swift) takes one language per note; this one is told which languages to
/// expect and writes each word in the language it was spoken. The audio of the note is sent.
enum OpenAITranscriber {
    static let model = "gpt-transcribe"
    /// OpenAI takes files up to 25 MB; at the 32 kbit/s the app writes, that is about 1.7 hours.
    static let largestFile = 25 * 1024 * 1024

    /// Without this, tried on 2026-10-14, a note whose language changed could come back with
    /// only one of its languages transcribed. With it, every word came back.
    private static let prompt = "A voice note by one person who switches between languages mid-sentence. " +
        "Write every word in the language it was spoken; do not translate."

    /// Transcribes the file. `languages` are hints in ISO 639-1 ("en", "de"); the model still
    /// writes what it hears, and reads a language outside the hints as well.
    static func transcribe(_ audio: URL, languages: [String], apiKey: String) async throws -> String {
        let data = try Data(contentsOf: audio)
        guard data.count <= largestFile else { throw OpenAITranscriberError.tooLarge }

        let boundary = "quasi-" + UUID().uuidString
        var body = Data()
        func field(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n")
        }
        field("model", model)
        field("response_format", "json")
        field("prompt", prompt)
        languages.forEach { field("languages[]", $0) }
        body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(audio.lastPathComponent)\"\r\nContent-Type: audio/mp4\r\n\r\n")
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n")

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (answer, response) = try await URLSession.shared.data(for: request)
        let json = (try? JSONSerialization.jsonObject(with: answer)) as? [String: Any] ?? [:]
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw OpenAITranscriberError.api((json["error"] as? [String: Any])?["message"] as? String ?? "The request to OpenAI failed.")
        }
        guard let text = json["text"] as? String else { throw OpenAITranscriberError.unreadable }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }
}
