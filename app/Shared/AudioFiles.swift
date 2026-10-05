import AVFoundation

/// The recorder writes two channels. The right one is the microphone; the left one mostly picks
/// up handling noise from the case. Everything this app saves or transcribes is the right channel
/// only, as mono AAC (Apple's platforms have no built-in MP3 encoder).
enum AudioFiles {
    static func voiceChannel(of channelCount: Int) -> Int {
        channelCount > 1 ? 1 : 0
    }

    /// Writes mono samples as an AAC `.m4a` file.
    static func writeVoice(samples: [Float], sampleRate: Double, to url: URL) throws {
        guard !samples.isEmpty,
              let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else {
            throw CocoaError(.fileWriteUnknown)
        }
        samples.withUnsafeBufferPointer { source in
            buffer.floatChannelData![0].update(from: source.baseAddress!, count: samples.count)
        }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        try? FileManager.default.removeItem(at: url)
        // 32 kbit/s mono matches the recorder's own 64 kbit/s for two channels.
        let settings: [String: Any] = [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: sampleRate,
                                       AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: 32_000]
        let file = try AVAudioFile(forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        try file.write(from: buffer)
    }

    /// Decodes a recording downloaded from the device and returns its voice channel.
    static func readVoice(from source: URL) throws -> (samples: [Float], sampleRate: Double) {
        let input = try AVAudioFile(forReading: source)
        let format = input.processingFormat
        let channel = voiceChannel(of: Int(format.channelCount))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 16_384) else {
            throw CocoaError(.fileReadUnknown)
        }
        var samples: [Float] = []
        samples.reserveCapacity(Int(input.length))
        while input.framePosition < input.length {
            try input.read(into: buffer)
            guard buffer.frameLength > 0, let channels = buffer.floatChannelData else { break }
            samples.append(contentsOf: UnsafeBufferPointer(start: channels[channel], count: Int(buffer.frameLength)))
        }
        return (samples, format.sampleRate)
    }
}
