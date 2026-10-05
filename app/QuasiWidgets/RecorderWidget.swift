import SwiftUI
import WidgetKit

/// The Lock Screen between recordings: the last note and what became of it, whether the recorder
/// is nearby, and its battery. If the app has not been heard from for hours while the recorder
/// was nearby, the widget says so by itself.
struct RecorderWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: LockSnapshot.widgetKind, provider: Provider()) { entry in
            RecorderWidgetView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Recorder")
        .description("Your last note and whether the recorder is nearby.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline])
    }

    struct Entry: TimelineEntry {
        var date: Date
        var snapshot: LockSnapshot
        /// The app has not refreshed the snapshot for longer than it is trusted.
        var silent = false
    }

    struct Provider: TimelineProvider {
        func placeholder(in context: Context) -> Entry {
            Entry(date: Date(), snapshot: LockSnapshot(link: .nearby, battery: 82, lastNote: "✓ Call the school office",
                                                       lastOutcome: "task added", lastNoteDate: Date()))
        }

        func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
            completion(context.isPreview ? placeholder(in: context) : Entry(date: Date(), snapshot: LockSnapshot.read()))
        }

        func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
            let snapshot = LockSnapshot.read()
            var entries = [Entry(date: Date(), snapshot: snapshot)]
            // Out of reach, the app sleeps and cannot refresh; only "nearby" can go silent.
            if snapshot.link == .nearby {
                let deadline = snapshot.updated.addingTimeInterval(LockSnapshot.trusted)
                if deadline <= Date() { entries[0].silent = true } else { entries.append(Entry(date: deadline, snapshot: snapshot, silent: true)) }
            }
            completion(Timeline(entries: entries, policy: .never))
        }
    }
}

struct RecorderWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RecorderWidget.Entry

    var body: some View {
        switch family {
        case .accessoryCircular: circle
        case .accessoryInline: Text(headline)
        default:
            VStack(alignment: .leading, spacing: 1) {
                Text(first).font(.headline).lineLimit(1)
                Text(second).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var snapshot: LockSnapshot { entry.snapshot }
    private func time(_ date: Date) -> String { date.formatted(date: .omitted, time: .shortened) }

    private var headline: String {
        if entry.silent { return "Quasi is not running" }
        switch snapshot.link {
        case .nearby: return "Recorder nearby"
        case .outOfReach: return "Recorder out of reach"
        case .bluetoothOff: return "Bluetooth is off"
        }
    }

    private var first: String {
        if entry.silent { return "No contact since \(time(snapshot.updated))" }
        switch snapshot.link {
        case .nearby: return snapshot.lastNote ?? "Recorder nearby"
        case .outOfReach: return "Recorder out of reach"
        case .bluetoothOff: return "Bluetooth is off"
        }
    }

    private var second: String {
        if entry.silent { return "Open Quasi to reconnect" }
        switch snapshot.link {
        case .nearby:
            guard let date = snapshot.lastNoteDate else { return "No notes yet" }
            return "Last note \(time(date))" + (snapshot.lastOutcome.map { " · \($0)" } ?? "")
        case .outOfReach: return "since \(time(snapshot.since)) · notes stay on it"
        case .bluetoothOff: return "Turn it on to hear the recorder"
        }
    }

    @ViewBuilder private var circle: some View {
        if !entry.silent, snapshot.link == .nearby, let battery = snapshot.battery {
            Gauge(value: Double(battery), in: 0...100) {
                Image(systemName: "waveform")
            } currentValueLabel: {
                Text("\(battery)")
            }
            .gaugeStyle(.accessoryCircularCapacity)
        } else {
            ZStack {
                Circle().strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [3, 3]))
                Text(entry.silent ? "!" : "–").font(.title3.weight(.semibold))
            }
            .padding(2)
        }
    }
}
