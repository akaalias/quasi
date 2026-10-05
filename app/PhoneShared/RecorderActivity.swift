import ActivityKit
import SwiftUI
import WidgetKit

/// The recorder's state on the Lock Screen and in the Dynamic Island: proof at a glance that the
/// app is still running and holding the link. In this folder because two targets need it: the
/// app starts and updates the activity, the widget extension draws it.
struct RecorderAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        enum Status: String, Codable {
            case connected, recording, transcribing, searching, bluetoothOff
        }

        var status: Status
        var battery: Int?
        /// When the recording in progress started.
        var recordingStart: Date?
        /// When the app last heard from the recorder.
        var lastContact: Date
    }
}

extension RecorderAttributes.ContentState {
    var glyph: String {
        switch status {
        case .recording: return "record.circle.fill"
        case .connected, .transcribing: return "waveform"
        case .searching, .bluetoothOff: return "antenna.radiowaves.left.and.right.slash"
        }
    }

    var title: String {
        switch status {
        case .connected: return "Recorder connected"
        case .recording: return "Recording"
        case .transcribing: return "Transcribing"
        case .searching: return "Recorder out of reach"
        case .bluetoothOff: return "Bluetooth is off"
        }
    }

    var tint: Color {
        switch status {
        case .recording: return .red
        case .connected, .transcribing: return .orange
        case .searching, .bluetoothOff: return .gray
        }
    }
}

struct RecorderLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecorderAttributes.self) { context in
            RecorderLockScreen(state: context.state, isStale: context.isStale)
                .activityBackgroundTint(Color(red: 0.09, green: 0.10, blue: 0.15))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let state = context.state
            let tint = context.isStale ? Color.gray : state.tint
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: state.glyph).font(.title2).foregroundStyle(tint).padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.isStale ? "Lost contact" : state.title).font(.headline).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    RecorderReadout(state: state).padding(.trailing, 4)
                }
            } compactLeading: {
                Image(systemName: state.glyph).foregroundStyle(tint)
            } compactTrailing: {
                RecorderReadout(state: state).frame(maxWidth: 48)
            } minimal: {
                Image(systemName: state.glyph).foregroundStyle(tint)
            }
        }
    }
}

/// The Lock Screen banner. `isStale` means the app has not refreshed the activity for several
/// minutes although the recorder was connected: the app is probably no longer running.
struct RecorderLockScreen: View {
    let state: RecorderAttributes.ContentState
    let isStale: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isStale ? "exclamationmark.triangle" : state.glyph)
                .font(.title)
                .foregroundStyle(isStale ? .yellow : state.tint)
                .frame(width: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(isStale ? "Lost contact" : state.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Group {
                    if isStale {
                        Text("Open Quasi to reconnect")
                    } else {
                        Text("Last heard at \(state.lastContact, style: .time)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
            }
            Spacer(minLength: 8)
            if !isStale {
                RecorderReadout(state: state).font(.title3).foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

/// The running time while recording, otherwise the recorder's battery level.
struct RecorderReadout: View {
    let state: RecorderAttributes.ContentState

    var body: some View {
        if state.status == .recording, let start = state.recordingStart {
            Text(start, style: .timer).monospacedDigit().multilineTextAlignment(.trailing)
        } else if let battery = state.battery, state.status != .searching, state.status != .bluetoothOff {
            Text("\(battery)%").monospacedDigit()
        }
    }
}
