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

/// Converts a temporary AVFoundation recording to 16 kHz mono: a
/// provider-friendly WAV (signed 16-bit PCM) or Float samples in memory for
/// the offline analyzer. A returned file remains temporary and is owned by
/// the caller, which must delete it after upload or analysis. No network
/// operation happens here.
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
        let source = try openSource(inputURL, fileManager: fileManager)
        guard let targetFormat = AVAudioFormat(
            commonFormat: targetCommonFormat,
            sampleRate: targetSampleRate,
            channels: targetChannelCount,
            interleaved: true
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

        try convert(source, to: targetFormat) { buffer in
            do {
                try destination.write(from: buffer)
            } catch {
                throw SpeechAudioConversionError.conversionFailed(error.localizedDescription)
            }
        }
        return destinationURL
    }

    /// The recording as 16 kHz mono Float samples, kept in memory only.
    public static func monoSamples16k(
        from inputURL: URL,
        fileManager: FileManager = .default
    ) throws -> [Float] {
        let source = try openSource(inputURL, fileManager: fileManager)
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: targetChannelCount,
            interleaved: false
        ) else {
            throw SpeechAudioConversionError.converterUnavailable
        }
        var samples: [Float] = []
        samples.reserveCapacity(Int(Double(source.length) * targetSampleRate / max(source.processingFormat.sampleRate, 1)))
        try convert(source, to: targetFormat) { buffer in
            guard let channel = buffer.floatChannelData?[0] else { return }
            samples.append(contentsOf: UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
        }
        return samples
    }

    private static func openSource(_ inputURL: URL, fileManager: FileManager) throws -> AVAudioFile {
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
        return source
    }

    private static func convert(
        _ source: AVAudioFile,
        to targetFormat: AVAudioFormat,
        consume: (AVAudioPCMBuffer) throws -> Void
    ) throws {
        guard let converter = AVAudioConverter(
            from: source.processingFormat,
            to: targetFormat
        ) else {
            throw SpeechAudioConversionError.converterUnavailable
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
                try consume(outputBuffer)
            }
            if status == .error {
                throw SpeechAudioConversionError.conversionFailed("Le convertisseur a renvoyé une erreur")
            }
            if status == .endOfStream {
                sourceFinished = true
            }
        }
    }
}
