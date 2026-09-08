import Foundation
import AVFoundation

public enum SpeechAudioConversionError: Error, LocalizedError, Sendable {
    case inputMissing
    case invalidInputFormat
    case converterUnavailable
    case conversionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .inputMissing:
            return "Le fichier audio temporaire est introuvable."
        case .invalidInputFormat:
            return "Le format audio enregistré n’est pas exploitable."
        case .converterUnavailable:
            return "La conversion audio n’est pas disponible sur cet appareil."
        case .conversionFailed(let message):
            return "La conversion audio a échoué" + (message.isEmpty ? "." : " : " + message)
        }
    }
}

/// Converts a temporary AVFoundation recording to a provider-friendly WAV.
/// The output is signed 16-bit PCM, 16 kHz, mono. The returned file remains
/// temporary and is owned by the caller, which must delete it after upload or
/// analysis. No network operation happens here.
public enum SpeechAudioConverter {
    public static let targetSampleRate = 16_000.0
    public static let targetChannelCount: AVAudioChannelCount = 1
    public static let targetCommonFormat: AVAudioCommonFormat = .pcmFormatInt16

    public static func makeWAV16kMono(
        from recording: Recording,
        fileManager: FileManager = .default
    ) throws -> URL {
        try makeWAV16kMono(from: recording.fileURL, fileManager: fileManager)
    }

    public static func makeWAV16kMono(
        from inputURL: URL,
        outputURL: URL? = nil,
        fileManager: FileManager = .default
    ) throws -> URL {
        guard fileManager.fileExists(atPath: inputURL.path) else {
            throw SpeechAudioConversionError.inputMissing
        }

        let source: AVAudioFile
        do {
            source = try AVAudioFile(forReading: inputURL)
        } catch {
            throw SpeechAudioConversionError.invalidInputFormat
        }
        guard source.length > 0 else {
            throw SpeechAudioConversionError.invalidInputFormat
        }

        guard let targetFormat = AVAudioFormat(
            commonFormat: targetCommonFormat,
            sampleRate: targetSampleRate,
            channels: targetChannelCount,
            interleaved: true
        ) else {
            throw SpeechAudioConversionError.converterUnavailable
        }
        guard let converter = AVAudioConverter(
            from: source.processingFormat,
            to: targetFormat
        ) else {
            throw SpeechAudioConversionError.converterUnavailable
        }

        let destinationURL = outputURL ?? fileManager.temporaryDirectory
            .appendingPathComponent("syllune-pronunciation-" + UUID().uuidString)
            .appendingPathExtension("wav")
        let destination: AVAudioFile
        do {
            destination = try AVAudioFile(
                forWriting: destinationURL,
                settings: targetFormat.settings,
                commonFormat: targetCommonFormat,
                interleaved: true
            )
        } catch {
            throw SpeechAudioConversionError.conversionFailed(error.localizedDescription)
        }

        let inputFrameCapacity: AVAudioFrameCount = 4_096
        let ratio = targetSampleRate / max(source.processingFormat.sampleRate, 1)
        let outputFrameCapacity = AVAudioFrameCount(
            max(1, Int(ceil(Double(inputFrameCapacity) * ratio)) + 1_024)
        )
        var sourceFinished = false
        var readError: Error?

        while !sourceFinished {
            guard let outputBuffer = AVAudioPCMBuffer(
                pcmFormat: targetFormat,
                frameCapacity: outputFrameCapacity
            ) else {
                throw SpeechAudioConversionError.converterUnavailable
            }

            var conversionError: NSError?
            let status = converter.convert(to: outputBuffer, error: &conversionError) { _, inputStatus in
                if sourceFinished {
                    inputStatus.pointee = .endOfStream
                    return nil
                }
                guard let inputBuffer = AVAudioPCMBuffer(
                    pcmFormat: source.processingFormat,
                    frameCapacity: inputFrameCapacity
                ) else {
                    readError = SpeechAudioConversionError.converterUnavailable
                    sourceFinished = true
                    inputStatus.pointee = .endOfStream
                    return nil
                }
                do {
                    try source.read(into: inputBuffer)
                } catch {
                    readError = error
                    sourceFinished = true
                    inputStatus.pointee = .endOfStream
                    return nil
                }
                guard inputBuffer.frameLength > 0 else {
                    sourceFinished = true
                    inputStatus.pointee = .endOfStream
                    return nil
                }
                inputStatus.pointee = .haveData
                return inputBuffer
            }

            if let readError { throw SpeechAudioConversionError.conversionFailed(readError.localizedDescription) }
            if let conversionError {
                throw SpeechAudioConversionError.conversionFailed(conversionError.localizedDescription)
            }
            if outputBuffer.frameLength > 0 {
                do {
                    try destination.write(from: outputBuffer)
                } catch {
                    throw SpeechAudioConversionError.conversionFailed(error.localizedDescription)
                }
            }
            if status == .error {
                throw SpeechAudioConversionError.conversionFailed("Le convertisseur a renvoyé une erreur")
            }
            if status == .endOfStream {
                sourceFinished = true
            }
        }

        return destinationURL
    }
}
