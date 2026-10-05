import SwiftUI

/// Waveform while the recorder is recording, then the transcript.
struct LiveView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if model.phase == .recording {
                WaveformView(levels: model.levels)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    Text(model.transcript.isEmpty ? placeholder : model.transcript)
                        .foregroundStyle(model.transcript.isEmpty ? .secondary : .primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if !model.taskNote.isEmpty {
                    Label(model.taskNote, systemImage: "checklist")
                        .font(.callout)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                footer
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            switch model.phase {
            case .recording:
                Circle().fill(.red).frame(width: 9, height: 9)
                Text("Recording").font(.headline)
                Spacer()
                if let start = model.recordingStart {
                    Text(start, style: .timer).monospacedDigit().foregroundStyle(.secondary)
                }
            case .transcribing:
                ProgressView().controlSize(.small)
                Text("Transcribing").font(.headline)
                Spacer()
            case .finished, .idle:
                Image(systemName: "text.quote")
                Text("Transcript").font(.headline)
                Spacer()
            }
        }
    }

    private var footer: some View {
        HStack {
            Text(model.transcriptNote)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer()
            Button("Copy") { model.copyTranscript() }
                .disabled(model.transcript.isEmpty)
        }
    }

    private var placeholder: String {
        model.phase == .transcribing ? "Working on it…" : "No transcript yet. Start a recording on the Note Pro."
    }
}

/// Scrolling level bars, newest on the right.
struct WaveformView: View {
    let levels: [Float]
    var color = Color.accentColor
    var barWidth: CGFloat = 2
    var step: CGFloat = 3.5

    var body: some View {
        Canvas { context, size in
            let capacity = Int(size.width / step)
            let visible = levels.suffix(capacity)
            let offset = size.width - CGFloat(visible.count) * step
            for (index, level) in visible.enumerated() {
                let height = max(2, CGFloat(level) * size.height)
                let rect = CGRect(x: offset + CGFloat(index) * step, y: (size.height - height) / 2,
                                  width: barWidth, height: height)
                context.fill(Path(roundedRect: rect, cornerRadius: barWidth / 2), with: .color(color))
            }
        }
    }
}
