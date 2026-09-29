import Foundation

/// A lesson played as one sequence of screens. Teaching content is placed just
/// before the first exercise that needs it instead of on a separate intro page:
/// a grammar note before its first linked exercise, a dialogue before the first
/// exercise built on its lines, a reading before its comprehension question.
/// Situation introductions, word cards and teaching blocks nothing refers to
/// keep their authored place, before the next exercise.
///
/// Progress stays keyed by exercise, so a checkpoint written by an older build
/// maps onto the same position.
public struct LessonFlow: Hashable, Sendable {
    /// Words shown together on one card screen.
    public static let wordsPerCard = 3

    public let steps: [LessonStep]
    public let exercises: [ExerciseBlock]
    /// Recaps and teaching blocks that no exercise follows. They belong to the
    /// end-of-lesson bilan rather than to a step.
    public let closingBlocks: [LessonBlock]
    /// The steps grouped into consecutive runs of one session phase, in
    /// order. A lesson without phases is one segment whose phase is nil.
    public let phaseSegments: [LessonPhaseSegment]
    /// Position in `steps` of each exercise, by exercise index.
    private let exerciseStepIndices: [Int]

    public init(lesson: LessonDocument) {
        self.init(blocks: lesson.blocks, vocabulary: lesson.vocabulary)
    }

    public init(blocks: [LessonBlock], vocabulary: [VocabularyEntry]) {
        let exercises = blocks.compactMap { block -> ExerciseBlock? in
            guard case .exercise(let exercise) = block else { return nil }
            return exercise
        }
        let knownVocabularyIDs = Set(vocabulary.map(\.id))
        var teachingBefore: [Int: [LessonTeachingStep]] = [:]
        var closingBlocks: [LessonBlock] = []
        var exercisesSeen = 0

        for block in blocks {
            switch block {
            case .exercise:
                exercisesSeen += 1
                continue
            case .recap:
                closingBlocks.append(block)
                continue
            case .introduction, .vocabulary, .dialogue, .reading:
                break
            }
            let authoredTarget = exercisesSeen < exercises.count ? exercisesSeen : nil
            guard let target = Self.firstConsumer(of: block, in: exercises) ?? authoredTarget else {
                closingBlocks.append(block)
                continue
            }
            teachingBefore[target, default: []] += Self.teachingSteps(for: block, knownVocabularyIDs: knownVocabularyIDs)
        }

        var steps: [LessonStep] = []
        var exerciseStepIndices: [Int] = []
        // Teaching steps take the phase of the exercise they prepare.
        var segments: [LessonPhaseSegment] = []
        for (index, exercise) in exercises.enumerated() {
            let start = steps.count
            steps += (teachingBefore[index] ?? []).map(LessonStep.teaching)
            exerciseStepIndices.append(steps.count)
            steps.append(.exercise(index: index, block: exercise))
            if let last = segments.last, last.phase == exercise.phase {
                segments[segments.count - 1] = LessonPhaseSegment(phase: last.phase, steps: last.steps.lowerBound..<steps.count)
            } else {
                segments.append(LessonPhaseSegment(phase: exercise.phase, steps: start..<steps.count))
            }
        }

        self.steps = steps
        self.exercises = exercises
        self.closingBlocks = closingBlocks
        self.phaseSegments = segments
        self.exerciseStepIndices = exerciseStepIndices
    }

    /// Position in `steps` of the exercise at `exerciseIndex`.
    public func stepIndex(ofExercise exerciseIndex: Int) -> Int? {
        exerciseStepIndices.indices.contains(exerciseIndex) ? exerciseStepIndices[exerciseIndex] : nil
    }

    /// The exercise a step stands for in the saved progress: the exercise
    /// itself, or the exercise a teaching step prepares. `exercises.count` past
    /// the last step.
    public func exerciseIndex(forStep stepIndex: Int) -> Int {
        exerciseStepIndices.firstIndex { $0 >= stepIndex } ?? exercises.count
    }

    /// Session phase of a step: its exercise's, or for a teaching step the
    /// phase of the exercise it prepares.
    public func phase(ofStep stepIndex: Int) -> LessonPhase? {
        let exerciseIndex = exerciseIndex(forStep: stepIndex)
        return exercises.indices.contains(exerciseIndex) ? exercises[exerciseIndex].phase : nil
    }

    /// The phase the next exercise opens, when it differs from the phase of
    /// the exercise at `exerciseIndex`; nil otherwise and after the last one.
    public func phaseStarting(afterExercise exerciseIndex: Int) -> LessonPhase? {
        guard exercises.indices.contains(exerciseIndex), exercises.indices.contains(exerciseIndex + 1) else { return nil }
        let next = exercises[exerciseIndex + 1].phase
        return next != exercises[exerciseIndex].phase ? next : nil
    }

    /// Step to open for a checkpoint saved at `exerciseIndex`. Pending work
    /// (a composed answer or visible feedback) reopens the exercise itself;
    /// otherwise the learner resumes on the teaching steps that prepare it, so
    /// a checkpoint written while reading a note or a dialogue lands there.
    /// Returns `steps.count` for a terminal position.
    public func resumeStepIndex(exerciseIndex: Int, hasPendingWork: Bool) -> Int {
        guard let exerciseStep = stepIndex(ofExercise: max(0, exerciseIndex)) else { return steps.count }
        guard !hasPendingWork else { return exerciseStep }
        var start = exerciseStep
        while start > 0, case .teaching = steps[start - 1] { start -= 1 }
        return start
    }

    private static func teachingSteps(for block: LessonBlock, knownVocabularyIDs: Set<VocabularyID>) -> [LessonTeachingStep] {
        switch block {
        case .introduction(let introduction):
            return [LessonTeachingStep(
                id: block.id.rawValue,
                kind: introduction.grammarPointID == nil ? .situation : .grammar,
                block: block
            )]
        case .vocabulary(let words):
            var seen: Set<VocabularyID> = []
            let ids = words.vocabularyIDs.filter { knownVocabularyIDs.contains($0) && seen.insert($0).inserted }
            let cards = stride(from: 0, to: ids.count, by: wordsPerCard).map { Array(ids[$0..<min($0 + wordsPerCard, ids.count)]) }
            return cards.enumerated().map { offset, cardIDs in
                LessonTeachingStep(
                    id: cards.count == 1 ? words.id.rawValue : "\(words.id.rawValue).\(offset + 1)",
                    kind: .words,
                    block: .vocabulary(VocabularyBlock(id: words.id, vocabularyIDs: cardIDs))
                )
            }
        case .dialogue:
            return [LessonTeachingStep(id: block.id.rawValue, kind: .dialogue, block: block)]
        case .reading:
            return [LessonTeachingStep(id: block.id.rawValue, kind: .reading, block: block)]
        case .exercise, .recap:
            return []
        }
    }

    private static func firstConsumer(of block: LessonBlock, in exercises: [ExerciseBlock]) -> Int? {
        switch block {
        case .introduction(let introduction):
            guard let grammarPointID = introduction.grammarPointID else { return nil }
            return exercises.firstIndex { $0.grammarPointID == grammarPointID }
        case .dialogue(let dialogue):
            let lines = Set(dialogue.lines.map { TextNormalizer.normalize($0.hanzi) })
            return exercises.firstIndex { exercise in
                dialogue.comprehensionExerciseIDs.contains(exercise.spec.id)
                    || quotedTexts(of: exercise.spec).contains { lines.contains(TextNormalizer.normalize($0)) }
            }
        case .reading(let reading):
            return exercises.firstIndex { reading.comprehensionExerciseIDs.contains($0.spec.id) }
        case .vocabulary, .exercise, .recap:
            return nil
        }
    }

    /// Mandarin sentences an exercise plays, shows or asks for verbatim. An
    /// exercise quoting a dialogue line is built on that dialogue.
    private static func quotedTexts(of spec: ExerciseSpec) -> [String] {
        switch spec {
        case .dictation(let exercise): return exercise.promptText.map { [$0] } ?? []
        case .listeningChoice(let exercise): return exercise.promptText.map { [$0] } ?? []
        case .conversationChoice(let exercise): return exercise.promptText.map { [$0] } ?? []
        case .speaking(let exercise): return [exercise.referenceText]
        case .fillBlank(let exercise): return exercise.canonicalSpeechSentence.map { [$0] } ?? []
        case .dialogueOrder(let exercise): return exercise.lines.map(\.hanzi)
        case .choice, .wordOrder, .handwriting, .flashcard, .matching, .toneDiscrimination, .translation:
            return []
        }
    }
}

public enum LessonStep: Hashable, Sendable, Identifiable {
    case teaching(LessonTeachingStep)
    case exercise(index: Int, block: ExerciseBlock)

    public var id: String {
        switch self {
        case .teaching(let step): return "teaching.\(step.id)"
        case .exercise(_, let block): return "exercise.\(block.spec.id.rawValue)"
        }
    }
}

/// A screen that presents content without evaluation; the learner continues
/// when ready.
public struct LessonTeachingStep: Hashable, Sendable, Identifiable {
    public enum Kind: String, Hashable, Sendable {
        case situation, words, grammar, dialogue, reading
    }

    /// The block ID, suffixed `.n` when a vocabulary block spans several cards.
    public let id: String
    public let kind: Kind
    /// The block to render. A word card carries only its own words.
    public let block: LessonBlock
}
