import AudioToolbox
import Foundation

/// What you hear and feel as a recording passes each step (see `LiveStep`), so the phone can
/// stay locked.
///
/// Two instruments, two meanings. Wood is the machinery: the note arrived, the transcript was
/// made. A soft chime is the conversation: the start of a recording asks a question, two rising
/// notes left hanging, and the end answers it. The answer says what happened: the plain home note
/// for nothing to do, one quick note per task added and then the home chord, or a fall that rings
/// out for a failure, a note that leaps up and away for a message sent on, or the opening question
/// again, higher, when the app has a question of its own and waits for the next recording to
/// answer it. A failure of the machinery is a dull wooden note, and nothing follows it.
///
/// While the transcript is being made or the note is being processed, and that takes more than a
/// moment, quiet alternating ticks say that the machinery is still at work.
///
/// The files are written by `tools/make_step_sounds.py`. They are system sounds, so they follow
/// the phone's ring/silent switch and volume.
///
/// Touch: a single short tap for a step that went well, two full vibrations for a failure.
@MainActor
final class StepSignals {
    /// The Taptic Engine's short, firm tap. Not a documented constant, but stable across iOS
    /// versions; the feedback generators from UIKit do nothing while the app is in the background.
    private static let tap: SystemSoundID = 1520

    /// How long a step may take before the ticking starts.
    private static let patience: TimeInterval = 1.2
    /// The ticking is one file of this length; it is started again if a step outlasts it.
    private static let tickingLength: TimeInterval = 29
    /// Ticking never outlasts this, whatever happens to the step it is waiting for.
    private static let longestWait: TimeInterval = 90

    /// Settings: both are on unless switched off.
    static let soundsKey = "stepSounds"
    static let tapsKey = "stepTaps"
    private var soundsOn: Bool { UserDefaults.standard.object(forKey: Self.soundsKey) as? Bool ?? true }
    private var tapsOn: Bool { UserDefaults.standard.object(forKey: Self.tapsKey) as? Bool ?? true }

    private var loaded: [String: SystemSoundID] = [:]
    private var ticking: Task<Void, Never>?

    /// Something was called off in the note being read: its answer begins with "never mind".
    private var calledOff = false

    func play(_ step: LiveStep) {
        if step == .calledOff {
            calledOff = true     // heard with the answer, not now: the ticking goes on
            return
        }
        // Work goes on after a note is captured and after it is transcribed; everything else ends it.
        ticking?.cancel()
        stopTicking()
        switch step {
        case .captured(true), .transcribed(true): startTicking()
        default: break
        }

        let name: String
        let failed: Bool
        switch step {
        case .started: (name, failed) = ("question", false)
        case .captured(let ok): (name, failed) = (ok ? "wood_1" : "wood_fail_1", !ok)
        case .transcribed(let ok): (name, failed) = (ok ? "wood_2" : "wood_fail_2", !ok)
        case .calledOff: return
        case .processed(.nothingToDo): (name, failed) = (calledOff ? "answer_cancelled" : "answer_nothing", false)
        case .processed(.tasksAdded(let count)): (name, failed) = ("answer_tasks_\(min(max(count, 1), 5))", false)
        case .processed(.remindersAdded(let count)): (name, failed) = ("answer_reminders_\(min(max(count, 1), 5))", false)
        case .processed(.timersStarted): (name, failed) = ("answer_timer", false)
        case .processed(.messagesSent): (name, failed) = ("answer_message", false)
        case .processed(.asking): (name, failed) = ("answer_asking", false)
        case .processed(.failed): (name, failed) = ("answer_failed", true)
        }
        // Called off, and something else was still done: "never mind" first, then that answer.
        let prefix = calledOff && name.hasPrefix("answer_") && name != "answer_cancelled" ? sound(named: "cancel") : nil
        if case .processed = step { calledOff = false }
        if soundsOn, let sound = sound(named: name) {
            if let prefix {
                AudioServicesPlaySystemSoundWithCompletion(prefix) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { AudioServicesPlaySystemSound(sound) }
                }
            } else {
                AudioServicesPlaySystemSound(sound)
            }
        }
        guard tapsOn else { return }
        if failed {
            AudioServicesPlaySystemSoundWithCompletion(kSystemSoundID_Vibrate) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                }
            }
        } else {
            AudioServicesPlaySystemSound(Self.tap)
        }
    }

    private func startTicking() {
        ticking = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.patience))
            let started = Date()
            while !Task.isCancelled, Date().timeIntervalSince(started) < Self.longestWait, self?.soundsOn == true {
                self?.playTicking()
                try? await Task.sleep(for: .seconds(Self.tickingLength))
            }
        }
    }

    /// The ticking as it plays, so that it can be cut off mid-file.
    private var tickingSound: SystemSoundID?

    private func playTicking() {
        stopTicking()
        guard let url = Bundle.main.url(forResource: "ticking", withExtension: "wav") else { return }
        var sound: SystemSoundID = 0
        guard AudioServicesCreateSystemSoundID(url as CFURL, &sound) == noErr else { return }
        tickingSound = sound
        AudioServicesPlaySystemSound(sound)
    }

    /// Disposing of a system sound is the only way to stop it before its end.
    private func stopTicking() {
        if let tickingSound {
            AudioServicesDisposeSystemSoundID(tickingSound)
        }
        tickingSound = nil
    }

    private func sound(named name: String) -> SystemSoundID? {
        if let sound = loaded[name] { return sound }
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { return nil }
        var sound: SystemSoundID = 0
        guard AudioServicesCreateSystemSoundID(url as CFURL, &sound) == noErr else { return nil }
        loaded[name] = sound
        return sound
    }
}
