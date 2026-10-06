import CoreBluetooth
import Foundation

enum RecorderError: LocalizedError {
    case notReady
    case disconnected
    case timeout
    case incomplete(received: Int, expected: Int)

    var errorDescription: String? {
        switch self {
        case .notReady: return "The recorder is not connected."
        case .disconnected: return "The recorder disconnected."
        case .timeout: return "The recorder stopped responding."
        case .incomplete(let received, let expected): return "Transfer incomplete (\(received) of \(expected) bytes)."
        }
    }
}

/// Bluetooth connection to the recorder. Finds it, keeps it connected, runs the handshake and
/// heartbeat, and exposes listing, download and the recorder's own events.
/// All CoreBluetooth callbacks arrive on the main queue.
@MainActor
final class RecorderClient: NSObject {
    enum State: Equatable {
        case bluetoothOff
        case searching
        case connecting
        case ready
        case paused
    }

    var onStateChange: ((State) -> Void)?
    var onBattery: ((Int) -> Void)?
    /// The recorder's storage: total and free, in megabytes.
    var onStorage: ((_ total: Int, _ free: Int) -> Void)?
    var onRecordingStarted: ((String) -> Void)?
    var onRecordingStopped: ((RecorderFile) -> Void)?
    var onRecordingFlag: ((Bool) -> Void)?
    var onLiveAudio: ((Data) -> Void)?
    /// The strength of the recorder's signal in dBm, after `readSignal()`.
    var onSignal: ((Int) -> Void)?
    /// Called for every frame from the recorder and on connect.
    var onActivity: (() -> Void)?

    private(set) var state: State = .searching {
        didSet { if state != oldValue { onStateChange?(state) } }
    }

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var commandCharacteristic: CBCharacteristic?
    private var pendingSubscriptions = 0
    private var heartbeat: Timer?
    private var heartbeatCount = 0
    private var paused = false

    private var listing: (files: [RecorderFile], continuation: CheckedContinuation<[RecorderFile], Error>)?
    private var listingTimeout: Timer?

    private struct Transfer {
        var expected: Int?
        var data = Data()
        var progress: (Int, Int) -> Void
        var continuation: CheckedContinuation<Data, Error>
        var lastActivity = Date()
    }
    private var transfer: Transfer?
    private var transferWatchdog: Timer?

    private let savedPeripheralKey = "recorderPeripheralIdentifier"

    override init() {
        super.init()
        let options = Platform.bluetoothRestoreIdentifier.map { [CBCentralManagerOptionRestoreIdentifierKey: $0] }
        central = CBCentralManager(delegate: self, queue: .main, options: options)
    }

    // MARK: Commands

    func listFiles() async throws -> [RecorderFile] {
        guard state == .ready, listing == nil else { throw RecorderError.notReady }
        return try await withCheckedThrowingContinuation { continuation in
            listing = ([], continuation)
            send(.listFiles, Data([0x01, 0xF4]))
            listingTimeout = Timer.scheduledTimer(withTimeInterval: 6, repeats: false) { [weak self] _ in
                Task { @MainActor in self?.finishListing() }
            }
        }
    }

    func download(_ file: RecorderFile, progress: @escaping (Int, Int) -> Void) async throws -> Data {
        guard state == .ready, transfer == nil else { throw RecorderError.notReady }
        return try await withCheckedThrowingContinuation { continuation in
            transfer = Transfer(progress: progress, continuation: continuation)
            send(.transfer, Data(file.name.utf8) + Data([0, 0, 0, 0]))
            transferWatchdog = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self, let transfer = self.transfer else { return }
                    if Date().timeIntervalSince(transfer.lastActivity) > 20 {
                        self.finishTransfer(.failure(RecorderError.timeout))
                    }
                }
            }
        }
    }

    /// Asks how strong the recorder's signal is. Nothing is sent to the recorder for this.
    func readSignal() {
        guard state == .ready else { return }
        peripheral?.readRSSI()
    }

    private func send(_ command: RecorderProtocol.Command, _ payload: Data = Data()) {
        guard let peripheral, let commandCharacteristic else { return }
        peripheral.writeValue(RecorderProtocol.frame(command, payload), for: commandCharacteristic, type: .withoutResponse)
    }

    // MARK: Connection

    /// Drops the link and stops looking for the recorder, so it can idle and a sleeping Mac is not
    /// woken by it. Holding the link (and the heartbeat) keeps the recorder awake.
    func pause() {
        guard !paused else { return }
        paused = true
        guard central.state == .poweredOn else { return }
        central.stopScan()
        state = .paused
        if let peripheral {
            central.cancelPeripheralConnection(peripheral)  // also cancels a pending connect
        }
        handleDisconnect()
    }

    func resume() {
        guard paused else { return }
        paused = false
        if central.state == .poweredOn {
            startSearching()
        }
    }

    private func startSearching() {
        state = .searching
        if let saved = UserDefaults.standard.string(forKey: savedPeripheralKey),
           let identifier = UUID(uuidString: saved),
           let known = central.retrievePeripherals(withIdentifiers: [identifier]).first {
            connect(known)
        }
        // The recorder advertises no service UUIDs, so scan for everything and match on name.
        central.scanForPeripherals(withServices: nil)
    }

    private func connect(_ target: CBPeripheral) {
        peripheral = target
        target.delegate = self
        central.connect(target)  // stays pending until the recorder is in range
    }

    private func handleDisconnect() {
        heartbeat?.invalidate()
        commandCharacteristic = nil
        pendingSubscriptions = 0
        if let listing {
            self.listing = nil
            listingTimeout?.invalidate()
            listing.continuation.resume(throwing: RecorderError.disconnected)
        }
        finishTransfer(.failure(RecorderError.disconnected))
        if central.state == .poweredOn, !paused {
            startSearching()
        }
    }

    // MARK: Incoming packets

    private func handleStatus(_ packet: Data) {
        guard let (command, payload) = RecorderProtocol.parse(packet) else { return }
        onActivity?()
        switch RecorderProtocol.Command(rawValue: command) {
        case .hello:
            // Echo the recorder's own code back. Never send 0x03 without it: an empty 0x03 unbinds the device.
            guard payload.count == 32 else { return }
            send(.confirm, payload + Data([0]))
        case .confirm:
            guard payload == Data([0]) else { return }
            send(.setTime, RecorderProtocol.timePayload())
            send(.deviceInfo)
            heartbeatCount = 0
            heartbeat = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.send(.heartbeat)
                    // Refresh the battery level every 5 minutes, but not in the middle of a download.
                    self.heartbeatCount += 1
                    if self.heartbeatCount % 30 == 0, self.transfer == nil {
                        self.send(.deviceInfo)
                    }
                }
            }
            state = .ready
        case .listFiles:
            guard listing != nil else { return }
            if payload.count == 24 {
                let name = String(decoding: payload[payload.startIndex + 1..<payload.startIndex + 20], as: UTF8.self)
                let size = RecorderProtocol.uint32(payload.suffix(4))
                listing?.files.append(RecorderFile(name: name, size: size))
            } else {
                finishListing()
            }
        case .transfer:
            guard transfer != nil else { return }
            if payload.count == 5 {
                transfer?.expected = RecorderProtocol.uint32(payload.suffix(4))
                transfer?.lastActivity = Date()
            } else if let current = transfer {
                let expected = current.expected ?? 0
                if current.data.count >= expected, expected > 0 {
                    finishTransfer(.success(current.data.prefix(expected)))
                } else {
                    finishTransfer(.failure(RecorderError.incomplete(received: current.data.count, expected: expected)))
                }
            }
        case .recordingStarted:
            guard payload.count >= 20 else { return }
            onRecordingStarted?(String(decoding: payload[payload.startIndex + 1..<payload.startIndex + 20], as: UTF8.self))
        case .recordingStopped:
            guard payload.count >= 25 else { return }
            let name = String(decoding: payload[payload.startIndex + 1..<payload.startIndex + 20], as: UTF8.self)
            let size = RecorderProtocol.uint32(payload[payload.startIndex + 21..<payload.startIndex + 25])
            onRecordingStopped?(RecorderFile(name: name, size: size))
        case .deviceInfo:
            guard payload.count >= 52 else { return }
            onBattery?(Int(payload[payload.startIndex + 9]))
            onStorage?(RecorderProtocol.uint32(payload.prefix(4)), RecorderProtocol.uint32(payload.dropFirst(4).prefix(4)))
        case .deviceStatus:
            // The standard Battery service always reads 100 %; the real level is here and in 0x05.
            guard payload.count >= 2 else { return }
            onBattery?(Int(payload[payload.startIndex + 1]))
            guard payload.count >= 12 else { return }
            onRecordingFlag?(payload[payload.startIndex + 11] != 0)
        default:
            break
        }
    }

    private func finishListing() {
        guard let listing else { return }
        self.listing = nil
        listingTimeout?.invalidate()
        listing.continuation.resume(returning: listing.files)
    }

    private func finishTransfer(_ result: Result<Data, Error>) {
        guard let transfer else { return }
        self.transfer = nil
        transferWatchdog?.invalidate()
        transfer.continuation.resume(with: result)
    }
}

extension RecorderClient: @preconcurrency CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state != .poweredOn {
            state = .bluetoothOff
        } else if paused {
            state = .paused
        } else if let peripheral, peripheral.state == .connected {
            linkEstablished(peripheral)  // restored by the system with the link still up
        } else {
            startSearching()
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        guard !paused, (advertisedName ?? peripheral.name) == RecorderProtocol.deviceName else { return }
        guard self.peripheral?.identifier != peripheral.identifier || peripheral.state == .disconnected else { return }
        connect(peripheral)
    }

    /// iOS removed the app from memory and has now relaunched it in the background because
    /// something happened on the link. Called before `centralManagerDidUpdateState`.
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        guard let restored = (dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral])?.first else { return }
        peripheral = restored
        restored.delegate = self
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard !paused else {
            central.cancelPeripheralConnection(peripheral)
            return
        }
        linkEstablished(peripheral)
    }

    private func linkEstablished(_ peripheral: CBPeripheral) {
        central.stopScan()
        onActivity?()
        UserDefaults.standard.set(peripheral.identifier.uuidString, forKey: savedPeripheralKey)
        state = .connecting
        peripheral.discoverServices([RecorderProtocol.service])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        handleDisconnect()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        handleDisconnect()
    }
}

extension RecorderClient: @preconcurrency CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for service in peripheral.services ?? [] {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for characteristic in service.characteristics ?? [] {
            switch characteristic.uuid {
            case RecorderProtocol.command:
                commandCharacteristic = characteristic
            case RecorderProtocol.status, RecorderProtocol.liveAudio, RecorderProtocol.storedAudio:
                pendingSubscriptions += 1
                peripheral.setNotifyValue(true, for: characteristic)
            default:
                break
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.service?.uuid == RecorderProtocol.service else { return }
        pendingSubscriptions -= 1
        // The recorder drops the connection within seconds unless the handshake follows.
        if pendingSubscriptions == 0 {
            send(.hello)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        guard error == nil else { return }
        onSignal?(RSSI.intValue)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let value = characteristic.value else { return }
        switch characteristic.uuid {
        case RecorderProtocol.status:
            handleStatus(value)
        case RecorderProtocol.liveAudio:
            onLiveAudio?(value)
        case RecorderProtocol.storedAudio:
            guard transfer != nil else { return }
            transfer?.data.append(value)
            transfer?.lastActivity = Date()
            if let current = transfer, let expected = current.expected {
                current.progress(current.data.count, expected)
            }
        default:
            break
        }
    }
}
