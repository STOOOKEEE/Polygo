import Foundation
import PolygoCore

/// The engine behind a pronunciation report. The enum names the integration
/// choice only; it does not imply that a provider is configured or available.
public enum SpeechPronunciationProvider: String, Codable, Hashable, Sendable, CaseIterable {
    case iflytek
    case speechSuper
    case offline
}

public enum SpeechPronunciationStatus: String, Codable, Hashable, Sendable {
    case completed
    case unconfigured
    case unavailable
    case failed
}

/// A provider's score for one expected word. Missing values are preserved as
/// nil rather than replaced with an invented zero.
public struct SpeechPronunciationWordScore: Codable, Hashable, Sendable, Identifiable {
    public let id: Int
    public let expected: String
    public let observed: String?
    public let score: Double?

    public init(id: Int, expected: String, observed: String? = nil, score: Double? = nil) {
        self.id = max(0, id)
        self.expected = expected
        self.observed = observed
        self.score = score.map(Self.clamp)
    }

    private static func clamp(_ value: Double) -> Double { min(1, max(0, value)) }
}

/// A provider's score for one phonetic unit. `observed` is optional because a
/// provider may report only a confidence for the expected sound.
public struct SpeechPronunciationSoundScore: Codable, Hashable, Sendable, Identifiable {
    public let id: Int
    public let expected: String
    public let observed: String?
    public let score: Double?

    public init(id: Int, expected: String, observed: String? = nil, score: Double? = nil) {
        self.id = max(0, id)
        self.expected = expected
        self.observed = observed
        self.score = score.map(Self.clamp)
    }

    private static func clamp(_ value: Double) -> Double { min(1, max(0, value)) }
}

/// A provider's score for one expected Mandarin tone.
public struct SpeechPronunciationToneScore: Codable, Hashable, Sendable, Identifiable {
    public let id: Int
    public let expected: Int?
    public let observed: Int?
    public let score: Double?

    public init(id: Int, expected: Int?, observed: Int? = nil, score: Double? = nil) {
        self.id = max(0, id)
        self.expected = expected.map { min(5, max(0, $0)) }
        self.observed = observed.map { min(5, max(0, $0)) }
        self.score = score.map(Self.clamp)
    }

    private static func clamp(_ value: Double) -> Double { min(1, max(0, value)) }
}

/// The complete provider response shown by the speaking surface. Thresholds
/// stay inside the provider adapter; the UI consumes the returned verdict.
public struct SpeechPronunciationReport: Codable, Hashable, Sendable {
    public let provider: SpeechPronunciationProvider
    public let verdict: SpeechPronunciationVerdict
    public let providerScore: Double?
    public let words: [SpeechPronunciationWordScore]
    public let sounds: [SpeechPronunciationSoundScore]
    public let tones: [SpeechPronunciationToneScore]
    /// Syllable-by-syllable detail of the offline analyzer: tones heard,
    /// pitch contours and the word check. Remote providers leave it nil.
    public let analysis: PronunciationAnalysis?

    public init(
        provider: SpeechPronunciationProvider,
        verdict: SpeechPronunciationVerdict,
        providerScore: Double? = nil,
        words: [SpeechPronunciationWordScore] = [],
        sounds: [SpeechPronunciationSoundScore] = [],
        tones: [SpeechPronunciationToneScore] = [],
        analysis: PronunciationAnalysis? = nil
    ) {
        self.provider = provider
        self.verdict = verdict
        self.providerScore = providerScore.map { min(1, max(0, $0)) }
        self.words = words
        self.sounds = sounds
        self.tones = tones
        self.analysis = analysis
    }

    /// Only a provider-completed pass or retry with its own score can become
    /// an `ExerciseAnswer`. An inconclusive report remains review-only.
    public var isAutomaticallyEvaluable: Bool {
        providerScore != nil && (verdict == .pass || verdict == .needsPractice)
    }

    public var persistedAssessment: SpeechPronunciationAssessment {
        SpeechPronunciationAssessment(
            providerID: provider.rawValue,
            verdict: verdict,
            providerScore: providerScore
        )
    }
}

/// A transport-safe result envelope. Error and unconfigured states carry no
/// report, so consumers cannot accidentally show synthetic words, tones, or a
/// zero score as if a provider had evaluated the recording.
public struct SpeechPronunciationResult: Codable, Hashable, Sendable {
    public let status: SpeechPronunciationStatus
    public let provider: SpeechPronunciationProvider?
    public let report: SpeechPronunciationReport?
    public let message: String?

    public init(
        status: SpeechPronunciationStatus,
        provider: SpeechPronunciationProvider? = nil,
        report: SpeechPronunciationReport? = nil,
        message: String? = nil
    ) {
        self.status = status
        self.provider = status == .completed ? report?.provider : provider
        self.report = status == .completed ? report : nil
        self.message = message
    }

    public static func completed(_ report: SpeechPronunciationReport) -> Self {
        Self(status: .completed, report: report)
    }

    public static func unconfigured(provider: SpeechPronunciationProvider? = nil, message: String? = nil) -> Self {
        Self(status: .unconfigured, provider: provider, message: message)
    }

    public static func unavailable(provider: SpeechPronunciationProvider? = nil, message: String? = nil) -> Self {
        Self(status: .unavailable, provider: provider, message: message)
    }

    public static func failed(provider: SpeechPronunciationProvider? = nil, message: String? = nil) -> Self {
        Self(status: .failed, provider: provider, message: message)
    }

    public var isAutomaticallyEvaluable: Bool {
        status == .completed && report?.isAutomaticallyEvaluable == true
    }
}

/// Provider-independent pronunciation evaluation. Implementations may be
/// local or remote; this contract performs no transport or authentication.
/// `transcript` is the on-device transcription of the same recording, nil
/// when dictation is not permitted or not available.
public protocol SpeechPronunciationService: Sendable {
    var provider: SpeechPronunciationProvider? { get }

    func evaluate(
        recording: Recording,
        exercise: SpeakingExercise,
        transcript: SpeechTranscript?
    ) async -> SpeechPronunciationResult
}

/// Composition without a provider, for previews and tests of the fallback
/// path. It returns an unconfigured state and never a score.
public struct UnconfiguredSpeechPronunciationService: SpeechPronunciationService, Sendable {
    public let provider: SpeechPronunciationProvider?

    public init(provider: SpeechPronunciationProvider? = nil) {
        self.provider = provider
    }

    public func evaluate(
        recording: Recording,
        exercise: SpeakingExercise,
        transcript: SpeechTranscript?
    ) async -> SpeechPronunciationResult {
        .unconfigured(provider: provider)
    }
}

/// On-device analysis: the recording is read into memory at 16 kHz mono,
/// its pitch is tracked syllable by syllable to check the tones, and the
/// transcript, when there is one, is compared with the expected words.
/// Nothing leaves the device. Consonants and vowels are not evaluated.
public struct OfflineSpeechPronunciationService: SpeechPronunciationService, Sendable {
    public let provider: SpeechPronunciationProvider? = .offline

    public init() {}

    public func evaluate(
        recording: Recording,
        exercise: SpeakingExercise,
        transcript: SpeechTranscript?
    ) async -> SpeechPronunciationResult {
        let samples: [Float]
        do {
            samples = try SpeechAudioConverter.monoSamples16k(from: recording.fileURL)
        } catch {
            return .failed(provider: .offline, message: error.localizedDescription)
        }
        guard !Task.isCancelled else {
            return .failed(provider: .offline, message: "Analyse annulée.")
        }
        let analysis = PronunciationAnalyzer().analyze(
            samples: samples,
            sampleRate: SpeechAudioConverter.targetSampleRate,
            exercise: exercise,
            transcript: transcript?.rawText
        )
        let report = SpeechPronunciationReport(
            provider: .offline,
            verdict: analysis.verdict,
            providerScore: analysis.score,
            analysis: analysis
        )
        return SpeechPronunciationResult(status: .completed, report: report, message: analysis.summary)
    }
}

/// Deterministic fixture service for UI and integration tests. It is kept in
/// the Apple target so tests can inject the same protocol as production code
/// without an upload, account, or paid provider.
public struct FixedSpeechPronunciationService: SpeechPronunciationService, Sendable {
    public let provider: SpeechPronunciationProvider?
    public let result: SpeechPronunciationResult

    public init(result: SpeechPronunciationResult) {
        self.result = result
        self.provider = result.provider
    }

    public func evaluate(
        recording: Recording,
        exercise: SpeakingExercise,
        transcript: SpeechTranscript?
    ) async -> SpeechPronunciationResult {
        result
    }
}
