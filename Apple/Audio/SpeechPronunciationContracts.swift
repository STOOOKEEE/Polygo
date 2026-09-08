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

    public init(
        provider: SpeechPronunciationProvider,
        verdict: SpeechPronunciationVerdict,
        providerScore: Double? = nil,
        words: [SpeechPronunciationWordScore] = [],
        sounds: [SpeechPronunciationSoundScore] = [],
        tones: [SpeechPronunciationToneScore] = []
    ) {
        self.provider = provider
        self.verdict = verdict
        self.providerScore = providerScore.map { min(1, max(0, $0)) }
        self.words = words
        self.sounds = sounds
        self.tones = tones
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
public protocol SpeechPronunciationService: Sendable {
    var provider: SpeechPronunciationProvider? { get }

    func evaluate(
        recording: Recording,
        exercise: SpeakingExercise
    ) async -> SpeechPronunciationResult
}

/// Live composition before a provider has been selected. It deliberately
/// returns an unconfigured state instead of pretending that local speech
/// transcription measures sounds or tones.
public struct UnconfiguredSpeechPronunciationService: SpeechPronunciationService, Sendable {
    public let provider: SpeechPronunciationProvider?

    public init(provider: SpeechPronunciationProvider? = nil) {
        self.provider = provider
    }

    public func evaluate(
        recording: Recording,
        exercise: SpeakingExercise
    ) async -> SpeechPronunciationResult {
        .unconfigured(provider: provider)
    }
}

/// The offline slot is explicit but intentionally unavailable until a real
/// phonetic model is integrated. No offline phoneme or tone score is inferred.
public struct OfflineSpeechPronunciationService: SpeechPronunciationService, Sendable {
    public let provider: SpeechPronunciationProvider? = .offline

    public init() {}

    public func evaluate(
        recording: Recording,
        exercise: SpeakingExercise
    ) async -> SpeechPronunciationResult {
        .unavailable(provider: .offline)
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
        exercise: SpeakingExercise
    ) async -> SpeechPronunciationResult {
        result
    }
}
