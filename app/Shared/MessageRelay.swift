import Foundation

enum MessageRelayError: LocalizedError {
    case notSetUp
    case api(String)

    var errorDescription: String? {
        switch self {
        case .notSetUp: return "The message relay is not set up."
        case .api(let message): return message
        }
    }
}

/// Sends a message from the owner's own number, with the phone locked in a pocket.
///
/// No app may send an iMessage itself. What an app can do is send the phone a text, and a
/// Shortcuts automation on the phone ("when a message containing `quasi|` arrives, run
/// immediately") can send a message on without asking, even locked. So the app texts the phone
/// `quasi|<number>|<text>` through Linq, a service with a line of its own, and the automation
/// splits the text and sends it to the number from the owner's own number. The round trip
/// takes a few seconds. The automation is set up once by hand; it cannot be installed by an app.
enum MessageRelay {
    static let marker = "quasi"

    struct Settings {
        var token: String
        var line: String
        var ownNumber: String

        /// The stored settings, if all three are there.
        static var stored: Settings? {
            guard let token = Keychain.read(.linqToken), let line = Keychain.read(.linqLine), let own = Keychain.read(.ownNumber) else { return nil }
            return Settings(token: token, line: line, ownNumber: own)
        }
    }

    /// What the automation on the phone receives. The separator cannot appear in the text.
    static func envelope(to number: String, text: String) -> String {
        let clean = text.replacingOccurrences(of: "|", with: "/").replacingOccurrences(of: "\n", with: " ")
        return "\(marker)|\(number)|\(clean)"
    }

    /// What the automation receives for a note to keep in Apple Notes: `quasi|note|<text>`.
    /// The shortcut makes a note of it instead of sending a message.
    static func noteEnvelope(_ text: String, recordedAt: Date) -> String {
        let heading = "Voice note, " + recordedAt.formatted(date: .abbreviated, time: .shortened)
        return "\(marker)|note|\(heading)\n\n\(text.replacingOccurrences(of: "|", with: "/"))"
    }

    /// Hands a plain note to the phone, to be kept in Apple Notes. Returns the relay's id for it.
    static func sendNote(_ text: String, recordedAt: Date, settings: Settings) async throws -> String {
        try await post(noteEnvelope(text, recordedAt: recordedAt), settings: settings)
    }

    /// Hands the message to the phone and returns the relay's id for it. The phone's automation
    /// does the sending; this only knows that the text reached the relay.
    static func send(to number: String, text: String, settings: Settings) async throws -> String {
        try await post(envelope(to: number, text: text), settings: settings)
    }

    private static func post(_ value: String, settings: Settings) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.linqapp.com/api/partner/v3/chats")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(settings.token)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "from": settings.line,
            "to": [settings.ownNumber],
            "message": ["parts": [["type": "text", "value": value]]],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status), let id = ((json["chat"] as? [String: Any])?["message"] as? [String: Any])?["id"] as? String else {
            let message = (json["error"] as? [String: Any])?["message"] as? String
            throw MessageRelayError.api(message ?? "The relay did not take the message (HTTP \(status)).")
        }
        return id
    }
}
