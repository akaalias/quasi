import Combine
import Foundation
import WidgetKit

/// Keeps the Lock Screen widgets (PhoneShared/LockSnapshot.swift) in step with the model.
/// iOS limits how often widgets redraw, so this only speaks when something changed, plus about
/// once an hour while the recorder is nearby, to show that the app is still running.
@MainActor
final class LockScreenPublisher {
    private static let refreshInterval: TimeInterval = 3600

    private let model: AppModel
    private var subscriptions: Set<AnyCancellable> = []

    init(model: AppModel) {
        self.model = model
        model.$connection.removeDuplicates().map { _ in () }
            .merge(with: model.$battery.removeDuplicates().map { _ in () }, model.$notes.map { _ in () })
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] in self?.publish() }
            .store(in: &subscriptions)
    }

    /// Called for every frame from the recorder.
    func linkIsAlive() {
        if Date().timeIntervalSince(LockSnapshot.read().updated) >= Self.refreshInterval {
            publish()
        }
    }

    private func publish() {
        let previous = LockSnapshot.read()
        var snapshot = LockSnapshot()
        switch model.connection {
        case .ready: snapshot.link = .nearby
        case .bluetoothOff: snapshot.link = .bluetoothOff
        default: snapshot.link = .outOfReach
        }
        snapshot.since = snapshot.link == previous.link ? previous.since : Date()
        snapshot.battery = model.battery ?? previous.battery
        if let note = model.notes.first {
            snapshot.lastNoteDate = note.date
            switch note.outcome {
            case .taskAdded:
                snapshot.lastNote = note.tasks.count == 1 ? "✓ " + note.tasks[0].draft.title : "✓ \(note.tasks.count) tasks added"
                snapshot.lastOutcome = note.tasks.count == 1 ? "task added" : note.tasks.map(\.draft.title).joined(separator: ", ")
            case .processingFailed, .transcriptionFailed, .noAudio:
                snapshot.lastNote = "A note needs a look"
                snapshot.lastOutcome = "open Quasi"
            case .note where note.isPartial:
                snapshot.lastNote = "A note needs a look"
                snapshot.lastOutcome = "open Quasi"
            case .pending:
                snapshot.lastNote = String(note.transcript.prefix(60))
                snapshot.lastOutcome = "reading"
            case .note:
                snapshot.lastNote = String(note.transcript.prefix(60))
                snapshot.lastOutcome = "kept as a note"
            }
        }
        var unchanged = snapshot
        unchanged.updated = previous.updated
        let stale = Date().timeIntervalSince(previous.updated) >= Self.refreshInterval
        guard unchanged != previous || stale else { return }
        snapshot.write()
        WidgetCenter.shared.reloadTimelines(ofKind: LockSnapshot.widgetKind)
    }
}
