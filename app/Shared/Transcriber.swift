import AVFoundation
import Speech

enum TranscriberError: LocalizedError {
    case unsupportedLanguage(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedLanguage(let identifier):
            return "Apple's on-device transcription does not support \(identifier)."
        }
    }
}

/// On-device speech-to-text with Apple's SpeechAnalyzer. Nothing leaves the device; the language
/// model is downloaded by the system the first time a language is used.
enum Transcriber {
    static func supportedLocales() async -> [Locale] {
        await SpeechTranscriber.supportedLocales.sorted { $0.identifier < $1.identifier }
    }

    static func transcribe(_ audio: URL, locale: Locale) async throws -> String {
        guard let supported = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            throw TranscriberError.unsupportedLanguage(locale.identifier)
        }
        let transcriber = SpeechTranscriber(locale: supported, preset: .transcription)
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }

        let collector = Task {
            var text = ""
            for try await result in transcriber.results {
                text += String(result.text.characters)
            }
            return text
        }

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let file = try AVAudioFile(forReading: audio)
        if let lastSample = try await analyzer.analyzeSequence(from: file) {
            try await analyzer.finalizeAndFinish(through: lastSample)
        } else {
            await analyzer.cancelAndFinishNow()
        }
        return try await collector.value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
