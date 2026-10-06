import Foundation

/// What happens to a recording, in order. After a failure the later steps do not happen.
enum LiveStep: Equatable {
    /// Live audio begins.
    case started
    /// The recording ended; `true` if audio of it is here or is being fetched from the recorder.
    case captured(Bool)
    /// `true` if audio and transcript of the whole recording are saved.
    case transcribed(Bool)
    /// The transcript was acted on.
    case processed(Processing)

    enum Processing: Equatable {
        /// Nothing was asked for, or nothing is set up to act on it.
        case nothingToDo
        case tasksAdded(Int)
        case failed
    }
}

/// What the live view is currently showing.
enum LivePhase: Equatable {
    case idle
    case recording
    case transcribing
    case finished
}

@MainActor
final class AppModel: ObservableObject {
    @Published var connection: RecorderClient.State = .searching
    @Published var battery: Int?
    /// The recorder's storage in megabytes, and what is stored on it. Nothing is ever deleted from
    /// the recorder by this app, so this only grows.
    @Published var storage: (total: Int, free: Int)?
    @Published var storedRecordings: (count: Int, megabytes: Double)?
    @Published var syncStatus = "Live recordings only"

    @Published var phase: LivePhase = .idle
    @Published var levels: [Float] = []
    @Published var recordingStart: Date?
    /// What has been understood of the recording in progress: the settled part, and the words
    /// still being worked out. Provisional; the saved transcript is made from the whole recording.
    @Published var liveText = ""
    @Published var liveTentative = ""
    @Published var transcript = ""
    /// Where the shown transcript comes from, and what is still in progress.
    @Published var transcriptNote = ""
    /// The task found in the transcript, or why there is none.
    @Published var taskNote = ""
    /// Every recording and what became of it, newest first.
    @Published private(set) var notes: [NoteRecord] = []
    /// Whether an Anthropic API key is stored; without one, transcripts are not checked for tasks.
    @Published private(set) var hasAnthropicKey = Keychain.read(.anthropicKey) != nil
    /// Whether a Todoist token is stored; without one, a task found is shown but not sent anywhere.
    @Published private(set) var hasTodoistToken = Keychain.read(.todoistToken) != nil

    @Published var availableLocales: [Locale] = []
    @Published var localeIdentifier: String {
        didSet { UserDefaults.standard.set(localeIdentifier, forKey: "transcriptionLocale") }
    }

    let folder = Platform.recordingsFolder

    /// Called when a live session starts (the Mac brings up its floating panel).
    var onLiveSessionStarted: (() -> Void)?
    /// Called as a recording passes or fails each step (the iPhone plays a sound for each).
    var onLiveStep: ((LiveStep) -> Void)?
    /// Called for every frame from the recorder and on connect (iOS uses it to stay awake in the background).
    var onLinkActivity: (() -> Void)? {
        didSet { client.onActivity = onLinkActivity }
    }

    // The platform decides when nobody is there to see the live view. While away the link is
    // dropped so the recorder can idle; a recording or download in progress is allowed to finish.
    var userIsAway = false {
        didSet { updateLink() }
    }
    var systemIsAsleep = false {
        didSet { updateLink() }
    }

    private let client = RecorderClient()
    private var decoder: LiveMP3Decoder?
    private var liveTranscriber: LiveTranscriber?
    private var liveSamples: [Float] = []
    private var pendingLevel: [Float] = []
    private var deviceIsRecording = false
    private var liveFileName: String?
    // What the live stream brought, for the recordings log.
    private var liveBytes = 0
    private var livePackets = 0
    private var lastLiveAudio: Date?
    private var longestLiveGap: TimeInterval = 0
    private var linkLosses = 0
    /// Signal strength every two seconds of the recording, in dBm.
    private var liveSignal: [Int] = []
    /// Runs while a recording waits for a lost link to come back.
    private var linkLostWait: Task<Void, Never>?
    private var fetching = false
    private var syncing = false
    private var syncRequested = false

    private static let levelWindow = 512   // samples per waveform bar (32 ms at 16 kHz)
    private static let maxLevels = 160

    init() {
        localeIdentifier = UserDefaults.standard.string(forKey: "transcriptionLocale") ?? Locale.current.identifier
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        notes = NoteLog.load(from: folder)

        client.onStateChange = { [weak self] state in
            guard let self, !self.staged else { return }
            self.connection = state
            if state == .ready {
                Task {
                    try? await Task.sleep(for: .seconds(4))
                    await self.countStoredRecordings()
                }
            }
            if state != .ready, self.phase == .recording {
                self.linkLostWhileRecording()
            }
        }
        client.onBattery = { [weak self] level in
            self?.battery = level
            self?.logBattery(level)
        }
        client.onStorage = { [weak self] total, free in
            self?.storage = (total, free)
            self?.noteRecorderState()
        }
        client.onRecordingFlag = { [weak self] recording in
            guard let self else { return }
            self.deviceIsRecording = recording
            // Back after a lost link, and the recorder has stopped meanwhile: its stop notice was missed.
            if !recording, self.phase == .recording, self.linkLostWait != nil,
               Date().timeIntervalSince(self.lastLiveAudio ?? .distantPast) > 2 {
                self.finishLiveSession(file: nil)
            }
        }
        client.onSignal = { [weak self] strength in
            guard let self, self.phase == .recording else { return }
            self.liveSignal.append(strength)
        }
        client.onRecordingStarted = { [weak self] name in self?.startLiveSession(name: name) }
        client.onLiveAudio = { [weak self] data in
            guard let self else { return }
            if self.phase != .recording { self.startLiveSession(name: nil) }
            self.noteLiveAudio(data.count)
            self.decoder?.feed(data)
        }
        client.onRecordingStopped = { [weak self] file in self?.finishLiveSession(file: file) }

        Task { availableLocales = await Transcriber.supportedLocales() }
    }

    // MARK: Staging

    private var staged = false

    /// Puts the model into a given state without a recorder, for design work and screenshots in
    /// the simulator, where there is no Bluetooth. Nothing in the app calls this in normal use.
    func stage(connection: RecorderClient.State, battery: Int?, recording: Bool) {
        staged = true
        self.connection = connection
        self.battery = battery
        guard recording else { return }
        phase = .recording
        recordingStart = Date().addingTimeInterval(-42)
        liveText = "So I was at the bank this morning and they need a form from me, the one for the joint account"
        liveTentative = " and they said it has to"
        var seed: UInt32 = 3
        levels = (0..<Self.maxLevels).map { _ in
            seed = seed &* 1_103_515_245 &+ 12_345
            return 0.15 + Float((seed >> 16) % 80) / 100
        }
    }

    // MARK: What is on the recorder

    /// Asks the recorder what it has stored. Skipped while it is recording or being downloaded from.
    func countStoredRecordings() async {
        guard connection == .ready, !deviceIsRecording, phase != .recording, !syncing, !fetching,
              let files = try? await client.listFiles() else { return }
        storedRecordings = (files.count, Double(files.reduce(0) { $0 + $1.size }) / 1_000_000)
        noteRecorderState()
        reconcile(with: files)
    }

    /// Checks the log against what the recorder has stored. The recorder knows how long each
    /// recording really is, which shows the notes that only partly arrived, and a recording made
    /// since the log began that has no entry gets one: nothing recorded goes unmentioned.
    private func reconcile(with files: [RecorderFile]) {
        guard let earliest = notes.map(\.date).min() else { return }
        var changed = false
        for file in files {
            if let index = notes.firstIndex(where: { $0.id == file.localBaseName }) {
                guard notes[index].recorded != file.seconds else { continue }
                notes[index].recorded = file.seconds
                changed = true
            } else if let date = file.startDate, date > earliest {
                notes.append(NoteRecord(id: file.localBaseName, date: date, recorded: file.seconds, outcome: .noAudio))
                record("\(file.localBaseName) is on the recorder (\(file.seconds) s) and was missing from the log")
                changed = true
            }
        }
        guard changed else { return }
        notes.sort { $0.date > $1.date }
        NoteLog.save(notes, to: folder)
    }

    /// Keeps the last known state of the recorder in `recorder.txt` in the log folder.
    private func noteRecorderState() {
        var lines = ["updated \(ISO8601DateFormatter().string(from: Date()))"]
        if let storage { lines.append("storage_total_mb \(storage.total)\nstorage_free_mb \(storage.free)") }
        if let storedRecordings { lines.append("recordings \(storedRecordings.count)\nrecordings_mb \(String(format: "%.1f", storedRecordings.megabytes))") }
        if let battery { lines.append("battery \(battery)") }
        try? FileManager.default.createDirectory(at: Platform.logsFolder, withIntermediateDirectories: true)
        try? lines.joined(separator: "\n").write(to: Platform.logsFolder.appendingPathComponent("recorder.txt"), atomically: true, encoding: .utf8)
    }

    // MARK: Link

    private func updateLink() {
        let busy = phase == .recording || syncing || fetching
        if systemIsAsleep || (userIsAway && !busy) {
            client.pause()
        } else if !userIsAway {
            client.resume()
        }
    }

    /// Appends the recorder's battery level to `battery.csv` in the platform's log folder.
    private func logBattery(_ level: Int) {
        appendLog("battery.csv", "\(ISO8601DateFormatter().string(from: Date())),\(level)")
    }

    /// Notes what happened to a recording in `recordings.log` in the platform's log folder, so a
    /// note that went wrong can be traced afterwards: how much arrived, when it stopped arriving.
    private func record(_ event: String) {
        appendLog("recordings.log", "\(ISO8601DateFormatter().string(from: Date())) \(event)")
    }

    private func appendLog(_ name: String, _ text: String) {
        let directory = Platform.logsFolder
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent(name)
        let line = Data((text + "\n").utf8)
        if let handle = try? FileHandle(forWritingTo: file) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: line)
        } else {
            try? line.write(to: file)
        }
    }

    var locale: Locale { Locale(identifier: localeIdentifier) }

    /// Supported languages, plus the current choice so a picker always has a matching entry.
    var languageChoices: [String] {
        var identifiers = availableLocales.map(\.identifier)
        if !identifiers.contains(localeIdentifier) {
            identifiers.insert(localeIdentifier, at: 0)
        }
        return identifiers
    }

    // MARK: Live recording

    private func startLiveSession(name: String?) {
        if phase == .recording {
            liveFileName = name ?? liveFileName
            return
        }
        deviceIsRecording = true
        liveFileName = name
        liveSamples = []
        liveBytes = 0
        livePackets = 0
        lastLiveAudio = nil
        longestLiveGap = 0
        linkLosses = 0
        liveSignal = []
        linkLostWait?.cancel()
        linkLostWait = nil
        pendingLevel = []
        levels = []
        transcript = ""
        transcriptNote = ""
        taskNote = ""
        recordingStart = Date()
        liveText = ""
        liveTentative = ""
        let decoder = LiveMP3Decoder()
        decoder.onSamples = { [weak self] samples in self?.appendLive(samples) }
        self.decoder = decoder
        let listener = LiveTranscriber()
        listener.onText = { [weak self] settled, tentative in
            guard let self, self.liveTranscriber === listener else { return }
            self.liveText = settled
            self.liveTentative = tentative
        }
        liveTranscriber = listener
        Task { await listener.start(locale: locale, sampleRate: decoder.sampleRate) }
        phase = .recording
        record("recording started (\(name ?? "name not known yet")), app \(Platform.appState)")
        let session = recordingStart
        Task { [weak self] in
            while let self, self.phase == .recording, self.recordingStart == session {
                self.client.readSignal()
                try? await Task.sleep(for: .seconds(2))
            }
        }
        onLiveSessionStarted?()
        onLiveStep?(.started)
    }

    private func noteLiveAudio(_ bytes: Int) {
        let now = Date()
        if let lastLiveAudio { longestLiveGap = max(longestLiveGap, now.timeIntervalSince(lastLiveAudio)) }
        lastLiveAudio = now
        liveBytes += bytes
        livePackets += 1
        if linkLostWait != nil {
            linkLostWait?.cancel()
            linkLostWait = nil
            record("audio arrives again")
        }
    }

    /// The link dropped during a recording. The recorder goes on recording, so the session stays
    /// open for a while: if the link comes back, the rest of the stream joins what is already
    /// here and the gap is filled from the recorder's own copy at the end.
    private func linkLostWhileRecording() {
        guard linkLostWait == nil else { return }
        linkLosses += 1
        let session = recordingStart
        record("link lost \(Int(Date().timeIntervalSince(session ?? Date()))) s into the recording")
        linkLostWait = Task { [weak self] in
            try? await Task.sleep(for: .seconds(30))
            guard let self, !Task.isCancelled, self.phase == .recording, self.recordingStart == session else { return }
            self.finishLiveSession(file: nil)
        }
    }

    private func appendLive(_ samples: [Float]) {
        liveSamples.append(contentsOf: samples)
        liveTranscriber?.feed(samples)
        pendingLevel.append(contentsOf: samples)
        var newLevels: [Float] = []
        while pendingLevel.count >= Self.levelWindow {
            let window = pendingLevel.prefix(Self.levelWindow)
            let rms = sqrt(window.reduce(0) { $0 + $1 * $1 } / Float(Self.levelWindow))
            // Map -55 dB ... -10 dB to 0 ... 1.
            newLevels.append(min(max((20 * log10(max(rms, 1e-6)) + 55) / 45, 0), 1))
            pendingLevel.removeFirst(Self.levelWindow)
        }
        guard !newLevels.isEmpty else { return }
        levels = Array((levels + newLevels).suffix(Self.maxLevels))
    }

    /// Ends the live session. If the live stream brought the recording (it always has small gaps),
    /// that is saved and transcribed. If a good part is missing, the complete copy is fetched
    /// from the recorder first. When that cannot be done, what arrived is kept, the note says how
    /// much is missing, and its words are not acted on: half a sentence makes a wrong task.
    private func finishLiveSession(file: RecorderFile?) {
        guard phase == .recording else { return }
        deviceIsRecording = false
        linkLostWait?.cancel()
        linkLostWait = nil
        let samples = liveSamples
        let sampleRate = decoder?.sampleRate ?? 16_000
        let started = recordingStart ?? Date()
        let source = file ?? liveFileName.map { RecorderFile(name: $0, size: 0) }
        let baseName = source?.localBaseName ?? RecorderFile.localBaseName(for: started)
        let kept = Int(Double(samples.count) / sampleRate)
        // The recorder names a recording after the moment it began, so how long it ran is known
        // without the stream.
        let recorded = max(kept, Int(Date().timeIntervalSince(source?.startDate ?? started)))
        let partial = samples.isEmpty || NoteRecord.isPartial(kept: kept, recorded: recorded)
        let fetchable = partial && source != nil && connection == .ready
        record("\(baseName) \(file == nil ? "ended without a stop notice" : "stopped"): recorded \(recorded) s, "
            + "kept \(String(format: "%.1f", Double(samples.count) / sampleRate)) s, "
            + "stream \(liveBytes) bytes in \(livePackets) packets, "
            + "last audio \(lastLiveAudio.map { String(format: "%.1f s after the start", $0.timeIntervalSince(started)) } ?? "never"), "
            + "longest gap \(String(format: "%.1f", longestLiveGap)) s, link lost \(linkLosses) times, "
            + "parser refused \(decoder?.parseFailures ?? 0) chunks, \(decoder?.decodeFailures ?? 0) packets did not decode, "
            + "size in stop notice \(file.map { String($0.size) } ?? "none"), "
            + "signal every 2 s \(liveSignal.map(String.init).joined(separator: " ")) dBm, app \(Platform.appState)")
        decoder = nil
        liveSamples = []
        liveFileName = nil
        liveTranscriber?.finish()
        liveTranscriber = nil
        fetching = fetchable  // so the link is not let go before the fetch begins
        updateLink()
        let nothingArrived = "No audio arrived from the recorder for this recording. It is still on the recorder."
        guard !samples.isEmpty || fetchable else {
            phase = .finished
            transcriptNote = nothingArrived
            log(NoteRecord(id: baseName, date: started, recorded: recorded, outcome: .noAudio))
            onLiveStep?(.captured(false))
            return
        }
        phase = .transcribing
        transcriptNote = fetchable ? "Fetching the whole recording from the recorder…" : "Transcribing…"
        onLiveStep?(.captured(true))

        Task {
            var audio = (samples: samples, sampleRate: sampleRate)
            var note = NoteRecord(id: baseName, date: started, seconds: kept, recorded: recorded)
            var fetched = false
            if fetchable, let source {
                do {
                    audio = try await fetchAudio(of: source)
                    note.seconds = Int(Double(audio.samples.count) / audio.sampleRate)
                    note.recorded = note.seconds
                    fetched = true
                    record("\(baseName) fetched whole from the recorder: \(note.seconds ?? 0) s")
                } catch {
                    record("\(baseName) could not be fetched from the recorder: \(error.localizedDescription)")
                }
            }
            guard !audio.samples.isEmpty else {
                self.log(NoteRecord(id: baseName, date: started, recorded: recorded, outcome: .noAudio))
                guard self.phase == .transcribing else { return }
                self.transcriptNote = nothingArrived
                self.phase = .finished
                self.onLiveStep?(.transcribed(false))
                return
            }
            if self.phase == .transcribing { self.transcriptNote = "Transcribing…" }
            do {
                note.transcript = try await saveAndTranscribe(samples: audio.samples, sampleRate: audio.sampleRate, baseName: baseName)
            } catch {
                note.outcome = .transcriptionFailed
                note.problem = error.localizedDescription
                self.log(note)
                guard self.phase == .transcribing else { return }
                self.transcriptNote = "Transcription failed: \(error.localizedDescription)"
                self.phase = .finished
                self.onLiveStep?(.transcribed(false))
                return
            }
            if fetched, let source { markComplete(source.name) }
            let current = self.phase == .transcribing
            if current {
                self.transcript = note.transcript
                self.phase = .finished
            }
            if let shortfall = note.shortfall {
                note.outcome = .note
                self.log(note)
                if current {
                    self.transcriptNote = shortfall + " The whole recording is still on the recorder."
                    self.onLiveStep?(.transcribed(false))
                }
                return
            }
            self.log(note)
            if current {
                self.transcriptNote = "Saved as \(baseName).txt"
                self.onLiveStep?(.transcribed(true))
            }
            let outcome = await self.process(baseName)
            if current { self.onLiveStep?(.processed(outcome)) }
        }
    }

    // MARK: The log

    /// Adds a note to the log, or replaces the one with the same id.
    private func log(_ note: NoteRecord) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index] = note
        } else {
            notes.append(note)
            notes.sort { $0.date > $1.date }
        }
        NoteLog.save(notes, to: folder)
    }

    private func update(_ id: String, _ change: (inout NoteRecord) -> Void) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        change(&notes[index])
        NoteLog.save(notes, to: folder)
    }

    // MARK: Tasks

    func setAnthropicKey(_ key: String?) {
        Keychain.write(key?.trimmingCharacters(in: .whitespacesAndNewlines), for: .anthropicKey)
        hasAnthropicKey = Keychain.read(.anthropicKey) != nil
    }

    func setTodoistToken(_ token: String?) {
        Keychain.write(token?.trimmingCharacters(in: .whitespacesAndNewlines), for: .todoistToken)
        hasTodoistToken = Keychain.read(.todoistToken) != nil
    }

    /// Asks Claude which tasks the note asks for and, with a Todoist token, adds them there.
    /// With `confirmed`, the user has said this note should become a task, so one is written.
    /// The result is kept in the log. Tasks that are found but cannot be sent anywhere (no
    /// Todoist token) count as nothing to do.
    @discardableResult
    func process(_ id: String, confirmed: Bool = false) async -> LiveStep.Processing {
        guard let note = notes.first(where: { $0.id == id }) else { return .nothingToDo }
        let show = { (text: String) in
            if self.notes.first?.id == id { self.taskNote = text }
        }
        guard !note.transcript.isEmpty, let key = Keychain.read(.anthropicKey) else {
            update(id) { $0.outcome = .note }
            return .nothingToDo
        }
        show("Looking for tasks…")
        update(id) { $0.outcome = .pending; $0.problem = nil }
        let token = Keychain.read(.todoistToken)
        // Where a task can be filed. Without it the task still goes to the inbox.
        var directory = TodoistClient.Directory()
        if let token, let fetched = try? await TodoistClient.directory(token: token) { directory = fetched }

        var tasks: [AddedTask]
        if !confirmed, note.outcome == .processingFailed, !note.tasks.isEmpty {
            // Trying again after Todoist refused some: the tasks are known, and those already added stay as they are.
            tasks = note.tasks
        } else {
            do {
                let drafts = try await TaskExtractor.extract(from: note.transcript, recordedAt: note.date, catalog: directory.catalog,
                                                             confirmed: confirmed, apiKey: key)
                guard !drafts.isEmpty else {
                    show("No task in this note")
                    update(id) { $0.outcome = .note; $0.tasks = [] }
                    return .nothingToDo
                }
                tasks = drafts.map { AddedTask(draft: $0) }
            } catch {
                show("Task check failed: \(error.localizedDescription)")
                update(id) { $0.outcome = .processingFailed; $0.problem = "The note could not be read for tasks: \(error.localizedDescription)" }
                return .failed
            }
        }
        let summary = Self.summary(of: tasks.map(\.draft))
        guard let token else {
            show("\(tasks.count == 1 ? "Task" : "Tasks"): \(summary)")
            update(id) { $0.outcome = .note; $0.tasks = tasks }
            return .nothingToDo
        }
        show("Adding to Todoist: \(summary)")
        var refusal: String?
        for index in tasks.indices where tasks[index].todoistID == nil {
            do {
                tasks[index].todoistID = try await TodoistClient.add(tasks[index].draft, in: directory, transcript: note.transcript,
                                                                     recordedAt: note.date, token: token)
            } catch {
                refusal = error.localizedDescription
            }
        }
        if let refusal {
            let missing = tasks.filter { $0.todoistID == nil }.count
            show("Not added to Todoist (\(refusal)): \(summary)")
            update(id) {
                $0.outcome = .processingFailed
                $0.tasks = tasks
                $0.problem = (tasks.count == 1 ? "Todoist did not take the task" : "Todoist did not take \(missing) of \(tasks.count) tasks") + ": \(refusal)"
            }
            return .failed
        }
        show("Added to Todoist: \(summary)")
        update(id) { $0.outcome = .taskAdded; $0.tasks = tasks }
        return .tasksAdded(tasks.count)
    }

    /// Removes what this note created in Todoist and keeps the note: one of its tasks, or all of them.
    func undoTask(_ id: String, index: Int? = nil) async {
        guard let note = notes.first(where: { $0.id == id }) else { return }
        let chosen = index.map { [$0] } ?? Array(note.tasks.indices)
        var remaining = note.tasks
        var refusal: String?
        for position in chosen.sorted(by: >) where remaining.indices.contains(position) {
            if let taskID = remaining[position].todoistID {
                guard let token = Keychain.read(.todoistToken) else { continue }
                do {
                    try await TodoistClient.remove(taskID: taskID, token: token)
                } catch {
                    refusal = error.localizedDescription
                    continue
                }
            }
            remaining.remove(at: position)
        }
        update(id) {
            $0.tasks = remaining
            $0.problem = refusal.map { "The task could not be removed: \($0)" }
            if remaining.isEmpty {
                $0.outcome = .note
            } else if remaining.allSatisfy({ $0.todoistID != nil }) {
                $0.outcome = .taskAdded
            }
        }
    }

    /// One line for the live view: a single task with whatever else was understood, several by their titles.
    static func summary(of drafts: [TaskDraft]) -> String {
        drafts.count == 1 ? summary(of: drafts[0]) : drafts.map(\.title).joined(separator: "; ")
    }

    /// One line for the live view: the title, then whatever else was understood.
    static func summary(of draft: TaskDraft) -> String {
        ([draft.title] + details(of: draft)).joined(separator: " · ")
    }

    /// What was understood about a task besides its title, in the order a reader wants it.
    static func details(of draft: TaskDraft) -> [String] {
        var parts: [String] = []
        if !draft.recurrence.isEmpty { parts.append(draft.recurrence) }
        if !draft.due.isEmpty { parts.append(draft.due) }
        if !draft.deadlineDate.isEmpty { parts.append("deadline \(draft.deadlineDate)") }
        if draft.priority > 0 { parts.append("p\(draft.priority)") }
        if draft.durationMinutes > 0 { parts.append("\(draft.durationMinutes) min") }
        if !draft.project.isEmpty { parts.append(draft.section.isEmpty ? draft.project : "\(draft.project) / \(draft.section)") }
        parts += draft.labels.map { "@\($0)" }
        return parts
    }

    /// Writes the voice channel as `<baseName>.m4a` and its transcript as `<baseName>.txt`.
    private func saveAndTranscribe(samples: [Float], sampleRate: Double, baseName: String) async throws -> String {
        let audio = folder.appendingPathComponent(baseName + ".m4a")
        try AudioFiles.writeVoice(samples: samples, sampleRate: sampleRate, to: audio)
        let text = try await Transcriber.transcribe(audio, locale: locale)
        try text.write(to: folder.appendingPathComponent(baseName + ".txt"), atomically: true, encoding: .utf8)
        return text
    }

    // MARK: The recorder's own copies

    /// Downloads one recording from the recorder and returns its voice channel.
    private func fetchAudio(of file: RecorderFile, progress: @escaping (Int, Int) -> Void = { _, _ in }) async throws -> (samples: [Float], sampleRate: Double) {
        fetching = true
        defer {
            fetching = false
            updateLink()
        }
        let data = try await client.download(file, progress: progress)
        // Kept next to the recordings: that folder can be written to while the phone is locked.
        let original = folder.appendingPathComponent(".fetch-\(UUID().uuidString).mp3")
        defer { try? FileManager.default.removeItem(at: original) }
        try data.write(to: original)
        return try AudioFiles.readVoice(from: original)
    }

    /// Remembers that the saved copy of a recording is the complete one, so it is not downloaded again.
    private func markComplete(_ name: String) {
        var complete = Set(UserDefaults.standard.stringArray(forKey: Self.completeKey) ?? [])
        complete.insert(name)
        UserDefaults.standard.set(Array(complete), forKey: Self.completeKey)
    }

    /// Replaces what this device has of one note with the recorder's complete copy and transcribes
    /// that. A note that has no tasks yet is then read for tasks; tasks already made stay.
    func fetchWhole(_ id: String) async {
        guard let note = notes.first(where: { $0.id == id }), let file = RecorderFile(localBaseName: id) else { return }
        guard connection == .ready, !deviceIsRecording, phase != .recording, !syncing else {
            update(id) { $0.problem = "The recorder is busy or out of reach, so the recording could not be fetched." }
            return
        }
        do {
            let audio = try await fetchAudio(of: file)
            let text = try await saveAndTranscribe(samples: audio.samples, sampleRate: audio.sampleRate, baseName: id)
            let length = Int(Double(audio.samples.count) / audio.sampleRate)
            markComplete(file.name)
            record("\(id) fetched whole from the recorder on request: \(length) s")
            update(id) {
                $0.transcript = text
                $0.seconds = length
                $0.recorded = length
                $0.problem = nil
                if $0.outcome == .noAudio || $0.outcome == .transcriptionFailed { $0.outcome = .note }
            }
            if note.tasks.isEmpty { await process(id) }
        } catch {
            record("\(id) could not be fetched from the recorder on request: \(error.localizedDescription)")
            update(id) { $0.problem = "The recording could not be fetched from the recorder: \(error.localizedDescription)" }
        }
    }

    // MARK: Download of stored recordings (manual)

    func requestSync() {
        guard connection == .ready, !deviceIsRecording, phase != .recording, !fetching else { return }
        if syncing {
            syncRequested = true
            return
        }
        syncing = true
        Task {
            repeat {
                syncRequested = false
                await sync()
            } while syncRequested
            syncing = false
            updateLink()
        }
    }

    /// Fetches the complete copies from the recorder. A complete copy replaces the audio and
    /// transcript saved from the live stream for the same recording.
    private func sync() async {
        do {
            syncStatus = "Checking recorder…"
            let files = try await client.listFiles()
            var complete = Set(UserDefaults.standard.stringArray(forKey: Self.completeKey) ?? [])
            var downloaded = 0
            for file in files {
                let audio = folder.appendingPathComponent(file.localBaseName + ".m4a")
                if complete.contains(file.name), FileManager.default.fileExists(atPath: audio.path) { continue }
                let (samples, sampleRate) = try await fetchAudio(of: file) { [weak self] received, total in
                    let percent = total > 0 ? received * 100 / total : 0
                    self?.syncStatus = "Downloading \(file.localBaseName) (\(percent)%)"
                }
                syncStatus = "Transcribing \(file.localBaseName)…"
                let text = try await saveAndTranscribe(samples: samples, sampleRate: sampleRate, baseName: file.localBaseName)
                let length = Int(Double(samples.count) / sampleRate)
                // The complete copy replaces what the live stream gave; a task already made from it stays.
                if notes.contains(where: { $0.id == file.localBaseName && $0.outcome == .taskAdded }) {
                    update(file.localBaseName) { $0.transcript = text; $0.seconds = length; $0.recorded = length }
                } else {
                    log(NoteRecord(id: file.localBaseName, date: file.startDate ?? Date(), seconds: length, recorded: length, transcript: text, outcome: .note))
                }
                complete.insert(file.name)
                UserDefaults.standard.set(Array(complete), forKey: Self.completeKey)
                downloaded += 1
            }
            let time = Date().formatted(date: .omitted, time: .shortened)
            syncStatus = downloaded == 0 ? "Up to date at \(time)" : "Downloaded \(downloaded) recording(s) at \(time)"
        } catch {
            syncStatus = "Download failed: \(error.localizedDescription)"
        }
    }

    private static let completeKey = "completeDownloads"

    // MARK: Actions

    func copyTranscript() {
        Platform.copy(transcript)
    }

    var connectionText: String {
        switch connection {
        case .bluetoothOff: return "Bluetooth is off"
        case .searching: return "Looking for the recorder…"
        case .connecting: return "Connecting…"
        case .ready: return battery.map { "Connected · battery \($0)%" } ?? "Connected"
        case .paused: return "Paused while you are away"
        }
    }
}
