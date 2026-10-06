import UIKit

/// What the shared code needs from the platform it runs on. Both folders are inside the app's
/// Documents folder, which the Files app shows under "On My iPhone".
enum Platform {
    private static let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    static let recordingsFolder = documents.appendingPathComponent("Recordings")
    static let logsFolder = documents.appendingPathComponent("Logs")

    /// Lets iOS relaunch the app in the background when the recorder connects or disconnects
    /// after the app was removed from memory.
    static let bluetoothRestoreIdentifier: String? = "recorder"

    /// Makes the app's folders and everything in them writable while the phone is locked.
    /// Recordings are saved in the background, and a file or folder with the stricter protection
    /// cannot be touched then. Has to run while the phone is unlocked to take effect.
    ///
    /// Never copy a whole folder into the app's container with `devicectl device copy to`: the
    /// folder arrives owned by root, and the app can then read it but not save into it. Let the
    /// app create its folders and copy files into them one by one (see tools/restore_phone.sh).
    static func openForBackgroundUse() {
        let manager = FileManager.default
        let relaxed: [FileAttributeKey: Any] = [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        for folder in [documents, recordingsFolder, logsFolder] {
            try? manager.createDirectory(at: folder, withIntermediateDirectories: true)
            try? manager.setAttributes(relaxed, ofItemAtPath: folder.path)
            for name in (try? manager.contentsOfDirectory(atPath: folder.path)) ?? [] {
                try? manager.setAttributes(relaxed, ofItemAtPath: folder.appendingPathComponent(name).path)
            }
        }
    }

    /// Where the app is right now, for the recordings log.
    @MainActor static var appState: String {
        let place = UIApplication.shared.applicationState == .active ? "in front" : "in the background"
        return UIApplication.shared.isProtectedDataAvailable ? place : place + ", phone locked"
    }

    static func copy(_ text: String) {
        UIPasteboard.general.string = text
    }
}
