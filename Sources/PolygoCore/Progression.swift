import Foundation

public enum LearningGoal: String, Codable, Hashable, Sendable, CaseIterable {
    case travel, conversation, study, work, explore
}

public enum AppearanceMode: String, Codable, Hashable, Sendable, CaseIterable {
    case system, light, dark
}

public struct LearnerPreferences: Codable, Hashable, Sendable {
    public let interfaceLanguage: String
    public let script: ChineseScript
    public let preferredSpeechLocale: String
    public let audioSpeed: Double
    public let showPinyin: Bool
    public let autoPlayAudio: Bool
    public let reminderDays: Set<Int>
    public let appearance: AppearanceMode
    public let reduceMotion: Bool

    public init(
        interfaceLanguage: String = "fr",
        script: ChineseScript = .simplified,
        preferredSpeechLocale: String = "zh-CN",
        audioSpeed: Double = 1,
        showPinyin: Bool = true,
        autoPlayAudio: Bool = false,
        reminderDays: Set<Int> = Set(1...7),
        appearance: AppearanceMode = .system,
        reduceMotion: Bool = false
    ) {
        self.interfaceLanguage = interfaceLanguage
        self.script = script
        self.preferredSpeechLocale = preferredSpeechLocale
        self.audioSpeed = min(2, max(0.5, audioSpeed))
        self.showPinyin = showPinyin
        self.autoPlayAudio = autoPlayAudio
        self.reminderDays = reminderDays.filter { (1...7).contains($0) }
        self.appearance = appearance
        self.reduceMotion = reduceMotion
    }

    private enum CodingKeys: String, CodingKey {
        case interfaceLanguage, script, preferredSpeechLocale, audioSpeed, showPinyin
        case autoPlayAudio, reminderDays, appearance, reduceMotion
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            interfaceLanguage: try c.decodeIfPresent(String.self, forKey: .interfaceLanguage) ?? "fr",
            script: try c.decodeIfPresent(ChineseScript.self, forKey: .script) ?? .simplified,
            preferredSpeechLocale: try c.decodeIfPresent(String.self, forKey: .preferredSpeechLocale) ?? "zh-CN",
            audioSpeed: try c.decodeIfPresent(Double.self, forKey: .audioSpeed) ?? 1,
            showPinyin: try c.decodeIfPresent(Bool.self, forKey: .showPinyin) ?? true,
            autoPlayAudio: try c.decodeIfPresent(Bool.self, forKey: .autoPlayAudio) ?? false,
            reminderDays: try c.decodeIfPresent(Set<Int>.self, forKey: .reminderDays) ?? Set(1...7),
            appearance: try c.decodeIfPresent(AppearanceMode.self, forKey: .appearance) ?? .system,
            reduceMotion: try c.decodeIfPresent(Bool.self, forKey: .reduceMotion) ?? false
        )
    }
}

public struct LearnerProfile: Codable, Hashable, Sendable {
    public let id: ProfileID
    public let nativeLanguage: String
    public let goal: LearningGoal
    public let dailyMinutes: Int
    public let selectedCourseID: CourseID
    public let preferences: LearnerPreferences
    public let createdAt: Date
    public let displayName: String?
    public let startingLevel: String

    public init(
        id: ProfileID,
        nativeLanguage: String = "fr",
        goal: LearningGoal = .conversation,
        dailyMinutes: Int = 10,
        selectedCourseID: CourseID,
        preferences: LearnerPreferences = LearnerPreferences(),
        createdAt: Date = Date(),
        displayName: String? = nil,
        startingLevel: String = "beginner"
    ) {
        self.id = id
        self.nativeLanguage = nativeLanguage
        self.goal = goal
        self.dailyMinutes = [5, 10, 15].contains(dailyMinutes) ? dailyMinutes : 10
        self.selectedCourseID = selectedCourseID
        self.preferences = preferences
        self.createdAt = createdAt
        self.displayName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.startingLevel = startingLevel
    }

    private enum CodingKeys: String, CodingKey {
        case id, nativeLanguage, goal, dailyMinutes, selectedCourseID, preferences, createdAt, displayName, startingLevel
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try c.decode(ProfileID.self, forKey: .id),
            nativeLanguage: try c.decodeIfPresent(String.self, forKey: .nativeLanguage) ?? "fr",
            goal: try c.decodeIfPresent(LearningGoal.self, forKey: .goal) ?? .conversation,
            dailyMinutes: try c.decodeIfPresent(Int.self, forKey: .dailyMinutes) ?? 10,
            selectedCourseID: try c.decode(CourseID.self, forKey: .selectedCourseID),
            preferences: try c.decodeIfPresent(LearnerPreferences.self, forKey: .preferences) ?? LearnerPreferences(),
            createdAt: try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date(timeIntervalSince1970: 0),
            displayName: try c.decodeIfPresent(String.self, forKey: .displayName),
            startingLevel: try c.decodeIfPresent(String.self, forKey: .startingLevel) ?? "beginner"
        )
    }

    public func updating(displayName: String?) -> LearnerProfile {
        LearnerProfile(id: id, nativeLanguage: nativeLanguage, goal: goal, dailyMinutes: dailyMinutes, selectedCourseID: selectedCourseID, preferences: preferences, createdAt: createdAt, displayName: displayName, startingLevel: startingLevel)
    }

    public func updating(preferences: LearnerPreferences) -> LearnerProfile {
        LearnerProfile(id: id, nativeLanguage: nativeLanguage, goal: goal, dailyMinutes: dailyMinutes, selectedCourseID: selectedCourseID, preferences: preferences, createdAt: createdAt, displayName: displayName, startingLevel: startingLevel)
    }

    public func updating(dailyMinutes: Int) -> LearnerProfile {
        LearnerProfile(id: id, nativeLanguage: nativeLanguage, goal: goal, dailyMinutes: dailyMinutes, selectedCourseID: selectedCourseID, preferences: preferences, createdAt: createdAt, displayName: displayName, startingLevel: startingLevel)
    }
}

public struct LessonProgress: Codable, Hashable, Sendable {
    public let lessonID: LessonID
    public let completedObjectiveIDs: Set<String>
    public let completedAt: Date?
    public let attemptCount: Int
    public let bestScore: Double
    public let lastOpenedAt: Date?
    public let answeredExerciseIDs: Set<ExerciseID>
    public let correctExerciseIDs: Set<ExerciseID>
    public let mistakeExerciseIDs: Set<ExerciseID>
    public let lastEvaluations: [ExerciseID: ExerciseEvaluation]

    public init(
        lessonID: LessonID,
        completedObjectiveIDs: Set<String> = [],
        completedAt: Date? = nil,
        attemptCount: Int = 0,
        bestScore: Double = 0,
        lastOpenedAt: Date? = nil,
        answeredExerciseIDs: Set<ExerciseID> = [],
        correctExerciseIDs: Set<ExerciseID> = [],
        mistakeExerciseIDs: Set<ExerciseID> = [],
        lastEvaluations: [ExerciseID: ExerciseEvaluation] = [:]
    ) {
        self.lessonID = lessonID; self.completedObjectiveIDs = completedObjectiveIDs; self.completedAt = completedAt
        self.attemptCount = max(0, attemptCount); self.bestScore = min(1, max(0, bestScore)); self.lastOpenedAt = lastOpenedAt
        self.answeredExerciseIDs = answeredExerciseIDs; self.correctExerciseIDs = correctExerciseIDs; self.mistakeExerciseIDs = mistakeExerciseIDs; self.lastEvaluations = lastEvaluations
    }

    public var answeredCount: Int { answeredExerciseIDs.count }
    public var correctCount: Int { correctExerciseIDs.count }
    public var completionRate: Double { answeredExerciseIDs.isEmpty ? 0 : Double(correctExerciseIDs.count) / Double(answeredExerciseIDs.count) }
}

public enum ReviewRating: Int, Codable, Hashable, Sendable, CaseIterable {
    case again = 0
    case againHard = 1
    case againSoft = 2
    case hard = 3
    case good = 4
    case easy = 5
}

public struct ReviewState: Codable, Hashable, Sendable {
    public let cardID: CardID
    public let repetition: Int
    public let intervalDays: Int
    public let easeFactor: Double
    public let dueAt: Date
    public let lastReviewedAt: Date?
    public let lapseCount: Int

    public init(cardID: CardID, repetition: Int = 0, intervalDays: Int = 0, easeFactor: Double = 2.5, dueAt: Date, lastReviewedAt: Date? = nil, lapseCount: Int = 0) {
        self.cardID = cardID; self.repetition = max(0, repetition); self.intervalDays = max(0, intervalDays); self.easeFactor = max(1.3, easeFactor); self.dueAt = dueAt; self.lastReviewedAt = lastReviewedAt; self.lapseCount = max(0, lapseCount)
    }

    public var isDue: Bool { dueAt <= Date() }
}

public struct ProgressSnapshot: Codable, Hashable, Sendable {
    public static let currentSchemaVersion = 1
    public let schemaVersion: Int
    public let profile: LearnerProfile?
    public let lessonProgress: [LessonID: LessonProgress]
    public let reviewStates: [CardID: ReviewState]
    public let lastEventLamport: UInt64
    public let generatedAt: Date
    public let processedEventIDs: Set<EventID>
    public let activeRoute: String?

    public init(
        schemaVersion: Int = ProgressSnapshot.currentSchemaVersion,
        profile: LearnerProfile? = nil,
        lessonProgress: [LessonID: LessonProgress] = [:],
        reviewStates: [CardID: ReviewState] = [:],
        lastEventLamport: UInt64 = 0,
        generatedAt: Date = Date(),
        processedEventIDs: Set<EventID> = [],
        activeRoute: String? = nil
    ) {
        self.schemaVersion = schemaVersion; self.profile = profile; self.lessonProgress = lessonProgress; self.reviewStates = reviewStates; self.lastEventLamport = lastEventLamport; self.generatedAt = generatedAt; self.processedEventIDs = processedEventIDs; self.activeRoute = activeRoute
    }

    public static func empty(now: Date = Date()) -> ProgressSnapshot { ProgressSnapshot(generatedAt: now) }
}

public enum ProgressEventPayload: Codable, Hashable, Sendable {
    case onboardingCompleted(profile: LearnerProfile)
    case lessonStarted(lessonID: LessonID, at: Date)
    case exerciseEvaluated(lessonID: LessonID, blockID: BlockID, evaluation: ExerciseEvaluation, at: Date)
    case lessonCompleted(lessonID: LessonID, at: Date)
    case flashcardAdded(cardID: CardID, at: Date)
    case flashcardReviewed(cardID: CardID, rating: ReviewRating, at: Date)
    case flashcardSuspended(cardID: CardID, suspended: Bool, at: Date)
    case recordingSaved(recordingID: RecordingID, exerciseID: ExerciseID, at: Date)
    case drawingSaved(drawingID: DrawingID, exerciseID: ExerciseID, at: Date)

    private enum CodingKeys: String, CodingKey { case kind, profile, lessonID, blockID, evaluation, exerciseID, cardID, rating, recordingID, drawingID, at, suspended }
    private enum Kind: String, Codable { case onboardingCompleted, lessonStarted, exerciseEvaluated, lessonCompleted, flashcardAdded, flashcardReviewed, flashcardSuspended, recordingSaved, drawingSaved }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(Kind.self, forKey: .kind) {
        case .onboardingCompleted: self = .onboardingCompleted(profile: try c.decode(LearnerProfile.self, forKey: .profile))
        case .lessonStarted: self = .lessonStarted(lessonID: try c.decode(LessonID.self, forKey: .lessonID), at: try c.decode(Date.self, forKey: .at))
        case .exerciseEvaluated: self = .exerciseEvaluated(lessonID: try c.decode(LessonID.self, forKey: .lessonID), blockID: try c.decode(BlockID.self, forKey: .blockID), evaluation: try c.decode(ExerciseEvaluation.self, forKey: .evaluation), at: try c.decode(Date.self, forKey: .at))
        case .lessonCompleted: self = .lessonCompleted(lessonID: try c.decode(LessonID.self, forKey: .lessonID), at: try c.decode(Date.self, forKey: .at))
        case .flashcardAdded: self = .flashcardAdded(cardID: try c.decode(CardID.self, forKey: .cardID), at: try c.decode(Date.self, forKey: .at))
        case .flashcardReviewed: self = .flashcardReviewed(cardID: try c.decode(CardID.self, forKey: .cardID), rating: try c.decode(ReviewRating.self, forKey: .rating), at: try c.decode(Date.self, forKey: .at))
        case .flashcardSuspended: self = .flashcardSuspended(cardID: try c.decode(CardID.self, forKey: .cardID), suspended: try c.decode(Bool.self, forKey: .suspended), at: try c.decode(Date.self, forKey: .at))
        case .recordingSaved: self = .recordingSaved(recordingID: try c.decode(RecordingID.self, forKey: .recordingID), exerciseID: try c.decode(ExerciseID.self, forKey: .exerciseID), at: try c.decode(Date.self, forKey: .at))
        case .drawingSaved: self = .drawingSaved(drawingID: try c.decode(DrawingID.self, forKey: .drawingID), exerciseID: try c.decode(ExerciseID.self, forKey: .exerciseID), at: try c.decode(Date.self, forKey: .at))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .onboardingCompleted(let profile): try c.encode(Kind.onboardingCompleted, forKey: .kind); try c.encode(profile, forKey: .profile)
        case .lessonStarted(let id, let date): try c.encode(Kind.lessonStarted, forKey: .kind); try c.encode(id, forKey: .lessonID); try c.encode(date, forKey: .at)
        case .exerciseEvaluated(let lesson, let block, let evaluation, let date): try c.encode(Kind.exerciseEvaluated, forKey: .kind); try c.encode(lesson, forKey: .lessonID); try c.encode(block, forKey: .blockID); try c.encode(evaluation, forKey: .evaluation); try c.encode(date, forKey: .at)
        case .lessonCompleted(let id, let date): try c.encode(Kind.lessonCompleted, forKey: .kind); try c.encode(id, forKey: .lessonID); try c.encode(date, forKey: .at)
        case .flashcardAdded(let id, let date): try c.encode(Kind.flashcardAdded, forKey: .kind); try c.encode(id, forKey: .cardID); try c.encode(date, forKey: .at)
        case .flashcardReviewed(let id, let rating, let date): try c.encode(Kind.flashcardReviewed, forKey: .kind); try c.encode(id, forKey: .cardID); try c.encode(rating, forKey: .rating); try c.encode(date, forKey: .at)
        case .flashcardSuspended(let id, let suspended, let date): try c.encode(Kind.flashcardSuspended, forKey: .kind); try c.encode(id, forKey: .cardID); try c.encode(suspended, forKey: .suspended); try c.encode(date, forKey: .at)
        case .recordingSaved(let recording, let exercise, let date): try c.encode(Kind.recordingSaved, forKey: .kind); try c.encode(recording, forKey: .recordingID); try c.encode(exercise, forKey: .exerciseID); try c.encode(date, forKey: .at)
        case .drawingSaved(let drawing, let exercise, let date): try c.encode(Kind.drawingSaved, forKey: .kind); try c.encode(drawing, forKey: .drawingID); try c.encode(exercise, forKey: .exerciseID); try c.encode(date, forKey: .at)
        }
    }
}

public struct ProgressEvent: Codable, Hashable, Sendable {
    public let eventID: EventID
    public let profileID: ProfileID
    public let deviceID: DeviceID
    public let lamport: UInt64
    public let occurredAt: Date
    public let schemaVersion: Int
    public let payload: ProgressEventPayload

    public init(eventID: EventID = EventID(rawValue: UUID().uuidString)!, profileID: ProfileID, deviceID: DeviceID, lamport: UInt64, occurredAt: Date = Date(), schemaVersion: Int = 1, payload: ProgressEventPayload) {
        self.eventID = eventID; self.profileID = profileID; self.deviceID = deviceID; self.lamport = lamport; self.occurredAt = occurredAt; self.schemaVersion = schemaVersion; self.payload = payload
    }
}

public protocol ProgressReducer: Sendable {
    func reduce(_ snapshot: ProgressSnapshot, event: ProgressEvent) throws -> ProgressSnapshot
}

public extension ProgressReducer {
    /// Convenience spelling for callers that pass the event positionally.
    /// The protocol requirement keeps the event label explicit at the storage
    /// boundary while this overload preserves the natural reducer call shape.
    func reduce(_ snapshot: ProgressSnapshot, _ event: ProgressEvent) throws -> ProgressSnapshot {
        try reduce(snapshot, event: event)
    }
}

public protocol PolygoClock: Sendable {
    func now() -> Date
}

public struct SystemPolygoClock: PolygoClock, Sendable {
    public init() {}
    public func now() -> Date { Date() }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
