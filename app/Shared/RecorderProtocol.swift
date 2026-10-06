import CoreBluetooth
import Foundation

/// Wire format of the Comulytic Note Pro, taken from a Bluetooth capture of the official app.
///
///     app -> recorder (F0F1):  80 08 02 <cmd> <len> <payload> <crc16>
///     recorder -> app (F0F2):  08 80 02 <cmd> <len> <payload> <crc16>
///
/// The request CRC is CRC-16/ARC over everything before it, big-endian.
/// Stored files arrive as raw bytes on F0F4, live audio as raw bytes on F0F3 (both MP3).
enum RecorderProtocol {
    static let deviceName = "Comulytic Note Pro"

    static let service = CBUUID(string: "F0F0")
    static let command = CBUUID(string: "F0F1")
    static let status = CBUUID(string: "F0F2")
    static let liveAudio = CBUUID(string: "F0F3")
    static let storedAudio = CBUUID(string: "F0F4")

    // Only the commands this app needs. The recorder has others, among them ones that delete
    // recordings or reset the device; they are deliberately not defined: this app never changes
    // or deletes anything on the recorder.
    enum Command: UInt8 {
        case hello = 0x02             // reply: 32-character token
        case confirm = 0x03           // token + 00; reply 00 = accepted
        case setTime = 0x04           // yy mm dd hh mm ss, UTC
        case deviceInfo = 0x05        // reply: 52 bytes, battery % at offset 9
        case recordingStarted = 0x06  // pushed by the recorder
        case recordingStopped = 0x07  // pushed by the recorder
        case listFiles = 0x0A
        case transfer = 0x0B          // name + offset; reply: size, then data, then 02
        case deviceStatus = 0x0F      // pushed by the recorder
        case heartbeat = 0x15         // every 10 s
    }

    static func frame(_ command: Command, _ payload: Data = Data()) -> Data {
        var packet = Data([0x80, 0x08, 0x02, command.rawValue, UInt8(payload.count)])
        packet.append(payload)
        let crc = crc16(packet)
        packet.append(UInt8(crc >> 8))
        packet.append(UInt8(crc & 0xFF))
        return packet
    }

    /// Splits a notification from F0F2 into command byte and payload.
    static func parse(_ packet: Data) -> (command: UInt8, payload: Data)? {
        let bytes = [UInt8](packet)
        guard bytes.count >= 7, bytes[0] == 0x08, bytes[1] == 0x80 else { return nil }
        let length = Int(bytes[4])
        guard bytes.count >= 5 + length else { return nil }
        return (bytes[3], Data(bytes[5..<(5 + length)]))
    }

    static func crc16(_ data: Data) -> UInt16 {
        var crc: UInt16 = 0
        for byte in data {
            crc ^= UInt16(byte)
            for _ in 0..<8 {
                crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xA001 : crc >> 1
            }
        }
        return crc
    }

    static func timePayload(_ date: Date = Date()) -> Data {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return Data([UInt8(parts.year! % 100), UInt8(parts.month!), UInt8(parts.day!),
                     UInt8(parts.hour!), UInt8(parts.minute!), UInt8(parts.second!)])
    }

    static func uint32(_ data: Data) -> Int {
        data.reduce(0) { ($0 << 8) | Int($1) }
    }
}

/// A recording stored on the device. `name` is the recorder's own identifier: its start time in UTC,
/// formatted `yyyy-MM-dd-HH-mm-ss`.
struct RecorderFile: Equatable {
    let name: String
    let size: Int

    var startDate: Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        return formatter.date(from: name)
    }

    /// Recordings are MP3 at a constant 64 kbit/s, so the size says how long one is.
    var seconds: Int { size / 8_000 }

    /// File name used for the saved copy, in local time.
    var localBaseName: String {
        startDate.map(Self.localBaseName(for:)) ?? name
    }

    static func localBaseName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return formatter.string(from: date)
    }
}

extension RecorderFile {
    /// The recording a saved copy was made from, by the copy's file name.
    init?(localBaseName: String) {
        let local = DateFormatter()
        local.locale = Locale(identifier: "en_US_POSIX")
        local.dateFormat = "yyyy-MM-dd HH.mm.ss"
        guard let date = local.date(from: localBaseName) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        self.init(name: formatter.string(from: date), size: 0)
    }
}
