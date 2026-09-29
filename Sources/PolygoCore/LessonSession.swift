import Foundation

/// Phase of a daily lesson an exercise belongs to (`metadata.stage`). The
/// phases follow each other in this order.
public enum LessonPhase: String, Codable, Hashable, Sendable, CaseIterable {
    case discover, guided, reuse

    public var title: String {
        switch self {
        case .discover: return "Découverte"
        case .guided: return "Pratique guidée"
        case .reuse: return "Réemploi"
        }
    }

    /// What Tavi says when the phase begins.
    public var announcement: String {
        switch self {
        case .discover: return "Découverte : on fait connaissance avec les mots !"
        case .guided: return "Pratique guidée : on assemble des phrases !"
        case .reuse: return "Réemploi : à toi de t’en servir !"
        }
    }
}

/// Consecutive steps of a lesson that share one phase.
public struct LessonPhaseSegment: Hashable, Sendable {
    public let phase: LessonPhase?
    public let steps: Range<Int>

    public init(phase: LessonPhase?, steps: Range<Int>) {
        self.phase = phase
        self.steps = steps
    }

    /// Share of the segment's steps already behind the learner standing on
    /// `stepIndex`, from 0 to 1.
    public func completion(atStep stepIndex: Int) -> Double {
        guard !steps.isEmpty else { return 0 }
        let done = min(max(stepIndex - steps.lowerBound, 0), steps.count)
        return Double(done) / Double(steps.count)
    }
}

/// First-try results of one lesson attempt, read in lesson order: accuracy
/// and runs of correct answers. A right answer after a retry does not count,
/// and an exercise without a scored answer neither extends nor breaks a run.
public struct LessonSessionStats: Hashable, Sendable {
    public let firstTryCorrectCount: Int
    public let firstTryAnsweredCount: Int
    public let bestStreak: Int
    /// Run of correct first tries ending at each exercise, by exercise index.
    private let runningStreaks: [Int]

    public init(exercises: [ExerciseBlock], firstAttempts: [ExerciseID: Bool]) {
        var correct = 0
        var answered = 0
        var streak = 0
        var best = 0
        var running: [Int] = []
        for exercise in exercises {
            if let result = firstAttempts[exercise.spec.id] {
                answered += 1
                if result {
                    correct += 1
                    streak += 1
                    best = max(best, streak)
                } else {
                    streak = 0
                }
            }
            running.append(streak)
        }
        firstTryCorrectCount = correct
        firstTryAnsweredCount = answered
        bestStreak = best
        runningStreaks = running
    }

    /// Correct first tries out of scored exercises, nil before any.
    public var accuracy: Double? {
        firstTryAnsweredCount == 0 ? nil : Double(firstTryCorrectCount) / Double(firstTryAnsweredCount)
    }

    /// Correct first tries in a row up to the exercise at `exerciseIndex`,
    /// included.
    public func streak(throughExercise exerciseIndex: Int) -> Int {
        guard exerciseIndex >= 0, let last = runningStreaks.indices.last else { return 0 }
        return runningStreaks[min(exerciseIndex, last)]
    }
}

/// What Tavi says after an evaluated exercise. Lines come from small fixed
/// pools, picked by step position so the same lesson always reads the same.
public struct TaviReaction: Hashable, Sendable {
    public enum Mood: Hashable, Sendable {
        case celebration, encouragement
    }

    /// Runs of correct first tries that get their own line.
    public static let streakMilestones: Set<Int> = [3, 5, 10, 15, 20]
    /// Streak shown in the lesson header from this length on.
    public static let visibleStreak = 3

    // The verdict (« Correct », « À revoir ») is shown next to Tavi; no line
    // repeats those words, so the reaction never reads as a second verdict.
    static let correctLines = [
        "Bravo, c’est exactement ça !",
        "Bien joué !",
        "Parfait, continue comme ça !",
        "Super, tu l’as !",
        "Excellent, tu progresses vite !"
    ]

    static let retryLines = [
        "Presque ! Regarde la bonne réponse, puis réessaie.",
        "Pas grave, on apprend en se trompant. Relis l’explication.",
        "Compare avec la bonne réponse et retente ta chance.",
        "Courage, tu vas y arriver ! Réessaie quand tu veux."
    ]

    static let incompleteLine = "Il manque encore ta réponse : complète-la, puis vérifie."

    public let mood: Mood
    public let message: String
    /// Announces the phase the next exercise opens.
    public let phaseAnnouncement: String?

    /// - Parameters:
    ///   - stepIndex: position of the exercise in the lesson's steps.
    ///   - streak: correct first tries in a row, this exercise included.
    ///   - nextPhase: the phase the following exercise opens, if any.
    /// Returns nil for a skipped exercise: there is nothing to react to.
    public init?(evaluation: ExerciseEvaluation, stepIndex: Int, streak: Int, nextPhase: LessonPhase?) {
        guard evaluation.outcome != .skipped else { return nil }
        let pick = max(0, stepIndex)
        if evaluation.countsAsCorrect {
            mood = .celebration
            message = Self.streakMilestones.contains(streak)
                ? "\(streak) bonnes réponses d’affilée, quelle série !"
                : Self.correctLines[pick % Self.correctLines.count]
        } else {
            mood = .encouragement
            message = evaluation.outcome == .unavailable
                ? Self.incompleteLine
                : Self.retryLines[pick % Self.retryLines.count]
        }
        phaseAnnouncement = nextPhase?.announcement
    }
}

/// Words the end-of-lesson screen lists.
public struct LessonWordsRecap: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        /// The words the lesson introduces.
        case learned
        /// A review or pinyin lesson introduces none: the words it revisits.
        case reviewed
    }

    public let kind: Kind
    public let words: [VocabularyEntry]

    /// New words (`metadata.newVocabularyIDs`), else the recap's words, each
    /// once and only when the lesson defines it. Nil when there are none.
    public init?(lesson: LessonDocument) {
        let entries = Dictionary(lesson.vocabulary.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        func resolve(_ ids: [VocabularyID]) -> [VocabularyEntry] {
            var seen: Set<VocabularyID> = []
            return ids.compactMap { id in seen.insert(id).inserted ? entries[id] : nil }
        }
        let learned = resolve(lesson.metadata?.newVocabularyIDs ?? [])
        if !learned.isEmpty {
            kind = .learned
            words = learned
            return
        }
        let reviewed = resolve(lesson.blocks.flatMap { block -> [VocabularyID] in
            guard case .recap(let recap) = block else { return [] }
            return recap.vocabularyIDs
        })
        guard !reviewed.isEmpty else { return nil }
        kind = .reviewed
        words = reviewed
    }
}
