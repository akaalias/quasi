import AudioToolbox
import AVFoundation

/// Decodes the recorder's live MP3 stream as it arrives and hands out the voice channel as PCM.
/// The live stream has small gaps (Bluetooth notifications are not retransmitted); the parser
/// resynchronises on the next frame header.
final class LiveMP3Decoder {
    /// Called with newly decoded samples of the voice channel.
    var onSamples: (([Float]) -> Void)?
    private(set) var sampleRate: Double = 16_000
    /// Chunks the parser refused and packets that did not decode, for the recordings log.
    private(set) var parseFailures = 0
    private(set) var decodeFailures = 0

    private var stream: AudioFileStreamID?
    private var inputFormat: AVAudioFormat?
    private var outputFormat: AVAudioFormat?
    private var converter: AVAudioConverter?

    init() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        AudioFileStreamOpen(context, { context, stream, property, _ in
            Unmanaged<LiveMP3Decoder>.fromOpaque(context).takeUnretainedValue().handleProperty(stream, property)
        }, { context, byteCount, packetCount, data, descriptions in
            Unmanaged<LiveMP3Decoder>.fromOpaque(context).takeUnretainedValue()
                .handlePackets(byteCount: byteCount, packetCount: packetCount, data: data, descriptions: descriptions)
        }, kAudioFileMP3Type, &stream)
    }

    deinit {
        if let stream { AudioFileStreamClose(stream) }
    }

    func feed(_ data: Data) {
        guard let stream else { return }
        data.withUnsafeBytes { bytes in
            if AudioFileStreamParseBytes(stream, UInt32(bytes.count), bytes.baseAddress, []) != noErr { parseFailures += 1 }
        }
    }

    private func handleProperty(_ stream: AudioFileStreamID, _ property: AudioFileStreamPropertyID) {
        guard property == kAudioFileStreamProperty_DataFormat else { return }
        var description = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        guard AudioFileStreamGetProperty(stream, property, &size, &description) == noErr,
              let input = AVAudioFormat(streamDescription: &description),
              let output = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: description.mSampleRate,
                                         channels: description.mChannelsPerFrame, interleaved: false) else { return }
        inputFormat = input
        outputFormat = output
        converter = AVAudioConverter(from: input, to: output)
        sampleRate = description.mSampleRate
    }

    private func handlePackets(byteCount: UInt32, packetCount: UInt32, data: UnsafeRawPointer,
                               descriptions: UnsafeMutablePointer<AudioStreamPacketDescription>?) {
        guard let converter, let inputFormat, let outputFormat, let descriptions,
              byteCount > 0, packetCount > 0 else { return }
        let compressed = AVAudioCompressedBuffer(format: inputFormat, packetCapacity: packetCount,
                                                 maximumPacketSize: Int(byteCount))
        memcpy(compressed.data, data, Int(byteCount))
        compressed.byteLength = byteCount
        compressed.packetCount = packetCount
        if let target = compressed.packetDescriptions {
            for index in 0..<Int(packetCount) { target[index] = descriptions[index] }
        }
        guard let pcm = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: (packetCount + 1) * 1152) else { return }

        var consumed = false
        var error: NSError?
        converter.convert(to: pcm, error: &error) { _, status in
            if consumed {
                status.pointee = .noDataNow
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return compressed
        }
        guard error == nil, pcm.frameLength > 0, let channels = pcm.floatChannelData else {
            decodeFailures += 1
            return
        }
        let channel = AudioFiles.voiceChannel(of: Int(outputFormat.channelCount))
        onSamples?(Array(UnsafeBufferPointer(start: channels[channel], count: Int(pcm.frameLength))))
    }
}
