import Foundation

/// What the Lock Screen widgets show between recordings. The app writes it whenever something
/// changes; the widget extension reads it. Both reach it through the shared app group.
struct LockSnapshot: Codable, Equatable {
    enum Link: String, Codable {
        case nearby, outOfReach, bluetoothOff
    }

    var link = Link.outOfReach
    /// When the link came into its present state.
    var since = Date()
    var battery: Int?
    /// The last note in one line, and what became of it.
    var lastNote: String?
    var lastOutcome: String?
    var lastNoteDate: Date?
    /// When the app last wrote this. A widget that has heard nothing for hours says so.
    var updated = Date()

    static let group = "group.com.alexisrondeau.Quasi"
    static let widgetKind = "RecorderStatus"
    /// How long a "nearby" snapshot is believed without a refresh from the app.
    static let trusted: TimeInterval = 3 * 3600
    private static let key = "lockSnapshot"

    static func read() -> LockSnapshot {
        guard let data = UserDefaults(suiteName: group)?.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(LockSnapshot.self, from: data) else { return LockSnapshot() }
        return snapshot
    }

    func write() {
        UserDefaults(suiteName: Self.group)?.set(try? JSONEncoder().encode(self), forKey: Self.key)
    }
}
