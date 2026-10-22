import ActivityKit
import AlarmKit
import SwiftUI
import WidgetKit

/// A timer started from a voice note ("set a timer for ten minutes, pasta"). AlarmKit counts it
/// down and rings it like the Clock app's timer; this is how it looks on the Lock Screen and in
/// the Dynamic Island while it runs. In this folder because the app starts it and the widget
/// extension draws it.
struct QuasiTimer: AlarmMetadata {
    /// What it is for, as said. Empty if nothing was.
    var label: String
}

struct TimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<QuasiTimer>.self) { context in
            TimerLockScreen(label: context.attributes.metadata?.label ?? "", mode: context.state.mode)
                .activityBackgroundTint(Color(red: 0.09, green: 0.10, blue: 0.15))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let label = context.attributes.metadata?.label ?? ""
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "timer").font(.title2).foregroundStyle(.orange).padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(label.isEmpty ? "Timer" : label).font(.headline).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TimerReadout(mode: context.state.mode).font(.title3).padding(.trailing, 4)
                }
            } compactLeading: {
                Image(systemName: "timer").foregroundStyle(.orange)
            } compactTrailing: {
                TimerReadout(mode: context.state.mode).frame(maxWidth: 56)
            } minimal: {
                Image(systemName: "timer").foregroundStyle(.orange)
            }
        }
    }
}

struct TimerLockScreen: View {
    let label: String
    let mode: AlarmPresentationState.Mode

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "timer").font(.title).foregroundStyle(.orange).frame(width: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(label.isEmpty ? "Timer" : label).font(.headline).foregroundStyle(.white)
                Text(isPaused ? "Paused" : "Started by Quasi").font(.caption).foregroundStyle(.white.opacity(0.6))
            }
            Spacer(minLength: 8)
            TimerReadout(mode: mode).font(.title).foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var isPaused: Bool {
        if case .paused = mode { return true }
        return false
    }
}

/// The time left: running while it counts down, still while paused.
struct TimerReadout: View {
    let mode: AlarmPresentationState.Mode

    var body: some View {
        switch mode {
        case .countdown(let countdown):
            Text(timerInterval: Date.now...max(Date.now, countdown.fireDate), countsDown: true)
                .monospacedDigit().multilineTextAlignment(.trailing)
        case .paused(let paused):
            Text(Duration.seconds(paused.totalCountdownDuration - paused.previouslyElapsedDuration),
                 format: .time(pattern: .minuteSecond))
                .monospacedDigit()
        default:
            Text("0:00").monospacedDigit()
        }
    }
}
