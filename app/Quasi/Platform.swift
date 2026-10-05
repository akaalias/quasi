import AppKit

/// What the shared code needs from the platform it runs on.
enum Platform {
    static let recordingsFolder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Recordings/Comulytic")
    static let logsFolder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/Quasi")

    /// The Mac app is never removed from memory by the system, so it needs no restoration.
    static let bluetoothRestoreIdentifier: String? = nil

    static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
