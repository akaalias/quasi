import AVFoundation
import Speech

/// Transcribes speech while it is still arriving, for the live view. What it reports is
/// provisional: the transcript that is saved is made afterwards from the whole recording.
@MainActor
final class LiveTranscriber {
    /// Called as the text grows: what is settled, and the words still being worked out.
    var onText: ((_ settled: String, _ tentative: String) -> Void)?

    private var input: AsyncStream<AnalyzerInput>.Continuation?
    private var analyzer: SpeechAnalyzer?
    private var results: Task<Void, Never>?
    private var converter: AVAudioConverter?
    private var source: AVAudioFormat?
    private var target: AVAudioFormat?
    private var pending: [[Float]] = []
    private var settled = ""

    /// Starts listening. Samples fed before this has finished are kept and passed on.
    func start(locale: Locale, sampleRate: Double) async {
        guard let supported = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else { return }
        let transcriber = SpeechTranscriber(locale: supported, preset: .progressiveTranscription)
        do {
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                try await request.downloadAndInstall()
            }
            guard let target = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]),
                  let source = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false) else { return }
            self.source = source
            self.target = target
            converter = AVAudioConverter(from: source, to: target)
            let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
            let analyzer = SpeechAnalyzer(modules: [transcriber])
            try await analyzer.start(inputSequence: stream)
            self.analyzer = analyzer
            input = continuation
        } catch {
            return
        }
        results = Task { [weak self] in
            do {
                for try await result in transcriber.results {
                    guard let self else { return }
                    let text = String(result.text.characters)
                    if result.isFinal {
                        self.settled += text
                        self.onText?(self.settled, "")
                    } else {
                        self.onText?(self.settled, text)
                    }
                }
            } catch {}
        }
        let waiting = pending
        pending = []
        waiting.forEach(feed)
    }

    func feed(_ samples: [Float]) {
        guard let input, let converter, let source, let target else {
            pending.append(samples)
            return
        }
        guard !samples.isEmpty, let buffer = AVAudioPCMBuffer(pcmFormat: source, frameCapacity: AVAudioFrameCount(samples.count)) else { return }
        samples.withUnsafeBufferPointer { buffer.floatChannelData![0].update(from: $0.baseAddress!, count: samples.count) }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        let capacity = AVAudioFrameCount(Double(samples.count) * target.sampleRate / source.sampleRate) + 64
        guard let converted = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }
        var consumed = false
        var error: NSError?
        converter.convert(to: converted, error: &error) { _, status in
            if consumed {
                status.pointee = .noDataNow
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return buffer
        }
        if error == nil, converted.frameLength > 0 {
            input.yield(AnalyzerInput(buffer: converted))
        }
    }

    /// Stops listening. Results already under way may still arrive.
    func finish() {
        input?.finish()
        input = nil
        let analyzer = analyzer
        Task { try? await analyzer?.finalizeAndFinishThroughEndOfInput() }
    }
}
