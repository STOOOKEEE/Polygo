import Foundation

/// A content-authored daily programme. The values describe the intended
/// allocation of a session; they are never presented as measured engagement.
public struct CoursePlan: Codable, Hashable, Sendable {
    public let targetMinutes: Int
    public let sessions: [CoursePlanSession]
    public let milestones: [CourseMilestone]
    public let catalogID: String?
    public let catalogVersion: String?

    public init(
        targetMinutes: Int = 15,
        sessions: [CoursePlanSession],
        milestones: [CourseMilestone] = [],
        catalogID: String? = nil,
        catalogVersion: String? = nil
    ) {
        self.targetMinutes = max(1, targetMinutes)
        self.sessions = sessions
        self.milestones = milestones
        self.catalogID = catalogID
        self.catalogVersion = catalogVersion
    }

    public var orderedSessions: [CoursePlanSession] {
        sessions.sorted { lhs, rhs in
            if lhs.day != rhs.day { return lhs.day < rhs.day }
            return lhs.lessonID.rawValue < rhs.lessonID.rawValue
        }
    }

    public func session(for lessonID: LessonID) -> CoursePlanSession? {
        orderedSessions.first { $0.lessonID == lessonID }
    }

    /// Returns the first authored day whose lesson has not been completed.
    /// Completion is deliberately based on stable lesson IDs, rather than the
    /// calendar, so a missed day never silently grants a curriculum milestone.
    public func nextSession(completedLessonIDs: Set<LessonID>) -> CoursePlanSession? {
        orderedSessions.first { !completedLessonIDs.contains($0.lessonID) }
    }

    /// The progressive day shown by Today. A completed programme remains on
    /// its final authored day so the UI can say that the programme is complete
    /// without inventing a day 91.
    public func currentDay(completedLessonIDs: Set<LessonID>) -> Int? {
        guard let first = orderedSessions.first else { return nil }
        return nextSession(completedLessonIDs: completedLessonIDs)?.day ?? orderedSessions.last?.day ?? first.day
    }

    public func completedSessionCount(completedLessonIDs: Set<LessonID>) -> Int {
        var count = 0
        for session in orderedSessions {
            guard completedLessonIDs.contains(session.lessonID) else { break }
            count += 1
        }
        return count
    }

    public func milestone(onOrBefore day: Int) -> CourseMilestone? {
        milestones.filter { $0.day <= day }.max { lhs, rhs in
            if lhs.day != rhs.day { return lhs.day < rhs.day }
            return lhs.id < rhs.id
        }
    }
}

public struct CoursePlanSession: Codable, Hashable, Sendable, Identifiable {
    public let day: Int
    public let lessonID: LessonID
    public let courseMinutes: Int
    public let reviewMinutes: Int

    public var id: Int { day }
    public var plannedMinutes: Int { courseMinutes + reviewMinutes }

    public init(day: Int, lessonID: LessonID, courseMinutes: Int, reviewMinutes: Int) {
        self.day = max(1, day)
        self.lessonID = lessonID
        self.courseMinutes = max(0, courseMinutes)
        self.reviewMinutes = max(0, reviewMinutes)
    }
}

public struct CourseMilestone: Codable, Hashable, Sendable, Identifiable {
    public let day: Int
    public let id: String
    public let title: LocalizedText
    public let reference: CurriculumTag?
    public let coverage: VocabularyCoverage?
    public let claims: [String]

    public init(
        day: Int,
        id: String,
        title: LocalizedText,
        reference: CurriculumTag? = nil,
        coverage: VocabularyCoverage? = nil,
        claims: [String] = []
    ) {
        self.day = max(1, day)
        self.id = id
        self.title = title
        self.reference = reference
        self.coverage = coverage
        self.claims = claims
    }
}

/// A target over canonical lexemes from one versioned catalogue. Extra words
/// used to make scenarios natural are intentionally excluded from this count.
public struct VocabularyCoverage: Codable, Hashable, Sendable {
    public let vocabularyTarget: Int
    public let newVocabularyTarget: Int?
    public let catalogID: String?
    public let catalogVersion: String?
    public let canonicalOnly: Bool

    public init(
        vocabularyTarget: Int,
        newVocabularyTarget: Int? = nil,
        catalogID: String? = nil,
        catalogVersion: String? = nil,
        canonicalOnly: Bool = true
    ) {
        self.vocabularyTarget = max(0, vocabularyTarget)
        self.newVocabularyTarget = newVocabularyTarget.map { max(0, $0) }
        self.catalogID = catalogID
        self.catalogVersion = catalogVersion
        self.canonicalOnly = canonicalOnly
    }
}
