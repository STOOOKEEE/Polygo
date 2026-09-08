import Foundation
import SwiftUI
import PolygoCore
import PolygoSRS
import PolygoPersistence
import PolygoApple

@MainActor
public final class AppModel: ObservableObject {
    public let dependencies: AppDependencies
    public let profileID: ProfileID

    @Published public private(set) var snapshot: ProgressSnapshot = .empty()
    @Published public private(set) var index: ContentIndex?
    @Published public private(set) var course: CourseManifest?
    @Published public private(set) var loadedLessons: [LessonID: LessonDocument] = [:]
    @Published public private(set) var isLoading = true
    @Published public private(set) var errorMessage: String?
    @Published public var selectedRoute: AppRoute = .today
    @Published public var preferredLanguageCodes: [String] = ["fr", "en"]

    private let defaults: UserDefaults
    // A journal active route is only a legacy bootstrap fallback. Once a
    // route has been persisted during this process, an in-flight reload must
    // not put the old journal route back into the UI.
    private var routePersistenceGeneration = 0
    private var legacyRouteRestoreAvailable: Bool
    private var loadTask: Task<Void, Never>?
    // Every progress event goes through one main-actor queue. Without this,
    // two answer changes arriving while a file append is suspended can both
    // be assigned the same Lamport value and the later checkpoint can replay
    // before the evaluation it describes.
    private var eventWriteTail: Task<Bool, Never>?
    private var startsInFlight: Set<LessonID> = []
    private var evaluationsInFlight: Set<String> = []
    private var completionsInFlight: Set<LessonID> = []

    public init(dependencies: AppDependencies, defaults: UserDefaults = .standard) {
        self.dependencies = dependencies
        self.defaults = defaults
        let storedID = defaults.string(forKey: "syllune.profile.id") ?? UUID().uuidString
        if defaults.string(forKey: "syllune.profile.id") == nil {
            defaults.set(storedID, forKey: "syllune.profile.id")
        }
        self.profileID = ProfileID(rawValue: storedID)!
        let storedRoute = defaults.string(forKey: "syllune.last.route")
        self.legacyRouteRestoreAvailable = storedRoute == nil
        if let rawRoute = storedRoute, let route = AppRoute(rawValue: rawRoute) {
            selectedRoute = route
        }
        loadTask = Task { [weak self] in await self?.reload() }
    }

    deinit { loadTask?.cancel() }

    public func reload() async {
        let restoreGeneration = routePersistenceGeneration
        let shouldRestoreLegacyRoute = legacyRouteRestoreAvailable
        legacyRouteRestoreAvailable = false
        isLoading = true
        defer { isLoading = false }
        do {
            async let loadedIndex = dependencies.content.index()
            async let loadedSnapshot = dependencies.progress.load(profileID: profileID)
            index = try await loadedIndex
            snapshot = try await loadedSnapshot
            if shouldRestoreLegacyRoute,
               routePersistenceGeneration == restoreGeneration,
               selectedRoute == .today,
               let activeRoute = snapshot.activeRoute.flatMap({ AppRoute(rawValue: $0) }),
               case .lesson(let activeLessonID) = activeRoute,
               snapshot.lessonProgress[activeLessonID]?.completedAt == nil {
                // Older installs may have an unfinished lesson in the
                // journal without a persisted UI route. Restore it once at
                // bootstrap, unless navigation changed while loading.
                persistRoute(activeRoute)
            }
            if let index {
                course = try await dependencies.content.course(id: snapshot.profile?.selectedCourseID ?? index.defaultCourseID)
            }
            errorMessage = nil
        } catch {
            // A first launch may not have a profile yet. The content error is
            // still shown so a missing bundle can be diagnosed honestly.
            if snapshot.profile == nil, let index {
                course = try? await dependencies.content.course(id: index.defaultCourseID)
            }
            errorMessage = "Impossible de charger les données de Syllune : \(error.localizedDescription)"
        }
    }

    public var needsOnboarding: Bool { snapshot.profile == nil }

    public var greeting: String {
        guard let name = snapshot.profile?.displayName, !name.isEmpty else { return "Bonjour" }
        return "Bonjour, \(name)"
    }

    public func loadLesson(_ id: LessonID) async -> LessonDocument? {
        if let existing = loadedLessons[id] { return existing }
        do {
            let lesson = try await dependencies.content.lesson(id: id)
            loadedLessons[id] = lesson
            return lesson
        } catch {
            errorMessage = "Cette leçon n’est pas disponible : \(error.localizedDescription)"
            return nil
        }
    }

    @discardableResult
    public func completeOnboarding(displayName: String?, level: String, minutes: Int, reminderDays: Set<Int>, goal: LearningGoal = .conversation) async -> Bool {
        let selectedCourse = snapshot.profile?.selectedCourseID ?? index?.defaultCourseID ?? CourseID(rawValue: "mandarin-starter")!
        let profile = LearnerProfile(
            id: profileID,
            goal: goal,
            dailyMinutes: minutes,
            selectedCourseID: selectedCourse,
            preferences: LearnerPreferences(reminderDays: reminderDays),
            createdAt: dependencies.clock.now(),
            displayName: displayName,
            startingLevel: level
        )
        let saved = await append(.onboardingCompleted(profile: profile))
        if course == nil { course = try? await dependencies.content.course(id: selectedCourse) }
        return saved
    }

    @discardableResult
    public func updateProfile(displayName: String?) async -> Bool {
        guard let current = snapshot.profile else { return false }
        // Profile edits are represented by a new onboarding payload so the
        // append-only journal remains usable by older sync clients.
        return await append(.onboardingCompleted(profile: current.updating(displayName: displayName)))
    }

    @discardableResult
    public func updatePreferences(_ preferences: LearnerPreferences) async -> Bool {
        guard let current = snapshot.profile else { return false }
        return await append(.onboardingCompleted(profile: current.updating(preferences: preferences)))
    }

    @discardableResult
    public func updateDailyMinutes(_ minutes: Int) async -> Bool {
        guard let current = snapshot.profile else { return false }
        return await append(.onboardingCompleted(profile: current.updating(dailyMinutes: minutes)))
    }

    @discardableResult
    public func startLesson(_ id: LessonID, persistRouteInNavigation: Bool = true) async -> Bool {
        guard startsInFlight.insert(id).inserted else {
            // Another destination task is already recording this opening.
            // Treat the second observation as successful without another
            // event; the first append owns the durable state.
            if persistRouteInNavigation { persistRoute(.lesson(id)) }
            return true
        }
        defer { startsInFlight.remove(id) }
        // SwiftUI can run a destination's task again after a tab switch or a
        // scene recreation. A lesson that already has an opening checkpoint
        // is already started; recording another opening would only inflate
        // the journal and move its timestamp for no learner-visible reason.
        if snapshot.lessonProgress[id]?.lastOpenedAt != nil {
            if persistRouteInNavigation { persistRoute(.lesson(id)) }
            return true
        }
        guard await append(.lessonStarted(lessonID: id, at: dependencies.clock.now())) else { return false }
        if persistRouteInNavigation { persistRoute(.lesson(id)) }
        return true
    }

    @discardableResult
    public func restartLesson(_ id: LessonID, persistRouteInNavigation: Bool = true) async -> Bool {
        guard completionsInFlight.insert(id).inserted else { return false }
        defer { completionsInFlight.remove(id) }
        guard await append(.lessonRestarted(lessonID: id, at: dependencies.clock.now())) else { return false }
        if persistRouteInNavigation { persistRoute(.lesson(id)) }
        return true
    }

    @discardableResult
    public func saveLessonCheckpoint(
        _ id: LessonID,
        exerciseIndex: Int,
        exerciseID: ExerciseID?,
        answer: ExerciseAnswer?,
        evaluation: ExerciseEvaluation?,
        dialogueDrafts: [BlockID: String] = [:],
        dialogueResults: [BlockID: Bool] = [:]
    ) async -> Bool {
        let normalizedIndex = max(0, exerciseIndex)
        // onDisappear and scenePhase can report the same state more than
        // once. Avoid creating a second event for an identical checkpoint.
        if let existing = snapshot.lessonProgress[id] {
            if existing.completedAt != nil { return true }
            if existing.currentExerciseIndex == normalizedIndex,
               existing.currentExerciseID == exerciseID,
               existing.pendingAnswer == answer,
               existing.pendingEvaluation == evaluation,
               existing.dialogueDrafts == dialogueDrafts,
               existing.dialogueResults == dialogueResults {
                return true
            }
        }
        return await append(.lessonCheckpointSaved(
            lessonID: id,
            exerciseIndex: normalizedIndex,
            exerciseID: exerciseID,
            answer: answer,
            evaluation: evaluation,
            dialogueDrafts: dialogueDrafts,
            dialogueResults: dialogueResults,
            at: dependencies.clock.now()
        ))
    }

    @discardableResult
    public func evaluate(_ spec: ExerciseSpec, answer: ExerciseAnswer, lessonID: LessonID, blockID: BlockID) async -> ExerciseEvaluation? {
        let key = "\(lessonID.rawValue)/\(spec.id.rawValue)"
        guard evaluationsInFlight.insert(key).inserted else { return nil }
        defer { evaluationsInFlight.remove(key) }
        let evaluation = dependencies.exerciseEngine.evaluate(spec: spec, answer: answer)
        guard await append(.exerciseEvaluated(lessonID: lessonID, blockID: blockID, evaluation: evaluation, at: dependencies.clock.now())) else { return nil }
        return evaluation
    }

    @discardableResult
    public func completeLesson(_ id: LessonID) async -> Bool {
        guard completionsInFlight.insert(id).inserted else { return false }
        defer { completionsInFlight.remove(id) }
        if snapshot.lessonProgress[id]?.completedAt == nil {
            guard await append(.lessonCompleted(lessonID: id, at: dependencies.clock.now()) ) else { return false }
        }
        if let lesson = await loadLesson(id) {
            for card in lesson.cards {
                // Completion can be durable before the process is killed
                // while cards are being added. Re-entering the completion
                // path repairs only missing cards and remains idempotent.
                guard snapshot.reviewStates[card.id] == nil else { continue }
                guard await append(.flashcardAdded(cardID: card.id, at: dependencies.clock.now()) ) else { return false }
            }
        }
        return true
    }

    @discardableResult
    public func addCard(_ id: CardID) async -> Bool {
        await append(.flashcardAdded(cardID: id, at: dependencies.clock.now()))
    }

    @discardableResult
    public func reviewCard(_ id: CardID, rating: ReviewRating) async -> Bool {
        await append(.flashcardReviewed(cardID: id, rating: rating, at: dependencies.clock.now()))
    }

    @discardableResult
    public func suspendCard(_ id: CardID, suspended: Bool) async -> Bool {
        await append(.flashcardSuspended(cardID: id, suspended: suspended, at: dependencies.clock.now()))
    }

    @discardableResult
    public func saveRecording(_ recordingID: RecordingID, exerciseID: ExerciseID) async -> Bool {
        await append(.recordingSaved(recordingID: recordingID, exerciseID: exerciseID, at: dependencies.clock.now()))
    }

    @discardableResult
    public func saveDrawing(_ drawingID: DrawingID, exerciseID: ExerciseID) async -> Bool {
        await append(.drawingSaved(drawingID: drawingID, exerciseID: exerciseID, at: dependencies.clock.now()))
    }

    public func persistRoute(_ route: AppRoute) {
        routePersistenceGeneration += 1
        legacyRouteRestoreAvailable = false
        selectedRoute = route
        defaults.set(route.rawValue, forKey: "syllune.last.route")
    }

    @discardableResult
    public func append(_ payload: ProgressEventPayload) async -> Bool {
        let previous = eventWriteTail
        let task = Task { @MainActor [weak self] in
            if let previous { _ = await previous.value }
            guard let self else { return false }
            return await self.appendNow(payload)
        }
        eventWriteTail = task
        return await task.value
    }

    private func appendNow(_ payload: ProgressEventPayload) async -> Bool {
        guard let profile = snapshot.profile ?? (payload.profileValue) else {
            // Before onboarding there is no valid profile-scoped event. The
            // onboarding action itself is the only allowed first event.
            return false
        }
        let event = ProgressEvent(
            profileID: profile.id,
            deviceID: deviceID,
            lamport: snapshot.lastEventLamport + 1,
            occurredAt: dependencies.clock.now(),
            payload: payload
        )
        do {
            snapshot = try await dependencies.progress.append(event)
            errorMessage = nil
            return true
        } catch {
            errorMessage = "La progression n’a pas été enregistrée : \(error.localizedDescription)"
            return false
        }
    }

    private var deviceID: DeviceID {
        let key = "syllune.device.id"
        let raw = defaults.string(forKey: key) ?? UUID().uuidString
        defaults.set(raw, forKey: key)
        return DeviceID(rawValue: raw)!
    }

    public var orderedLessonIDs: [LessonID] {
        course?.modules.sorted { $0.order < $1.order }.flatMap(\.lessonIDs) ?? []
    }

    public var streakDays: Int {
        let days = snapshot.lessonProgress.values.compactMap { $0.completedAt }.map { Calendar.current.startOfDay(for: $0) }
        guard !days.isEmpty else { return 0 }
        let unique = Set(days)
        var cursor = Calendar.current.startOfDay(for: dependencies.clock.now())
        var count = 0
        while unique.contains(cursor) {
            count += 1
            guard let previous = Calendar.current.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    public func card(for vocabularyID: VocabularyID) -> ReviewCard? {
        loadedLessons.values
            .sorted { $0.order < $1.order }
            .flatMap(\.cards)
            .first { $0.vocabularyID == vocabularyID }
    }

    public func reviewCard(for cardID: CardID) -> ReviewCard? {
        loadedLessons.values.sorted { $0.order < $1.order }.flatMap(\.cards).first { $0.id == cardID }
    }

    public func isLessonUnlocked(_ id: LessonID) -> Bool {
        guard let course else { return false }
        guard let module = course.modules.first(where: { $0.lessonIDs.contains(id) }), module.lessonIDs.contains(id) else { return false }
        let ordered = orderedLessonIDs
        guard let position = ordered.firstIndex(of: id) else { return false }
        if position == 0 { return true }
        let previous = ordered[position - 1]
        return snapshot.lessonProgress[previous]?.completedAt != nil
    }

    public var nextLessonID: LessonID? {
        resumeLessonID
    }

    /// Prefer the unfinished lesson opened most recently, then fall back to
    /// the first unlocked lesson in the course. This keeps the home action a
    /// true "Continuer" action after leaving a lesson midway.
    public var resumeLessonID: LessonID? {
        let unfinished = orderedLessonIDs.compactMap { id -> (LessonID, Date)? in
            guard isLessonUnlocked(id), let progress = snapshot.lessonProgress[id], progress.completedAt == nil,
                  let opened = progress.lastOpenedAt else { return nil }
            return (id, opened)
        }
        if let mostRecent = unfinished.max(by: { lhs, rhs in
            if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
            return lhs.0.rawValue < rhs.0.rawValue
        }) {
            return mostRecent.0
        }
        return orderedLessonIDs.first(where: { isLessonUnlocked($0) && snapshot.lessonProgress[$0]?.completedAt == nil })
    }

    public func dictionaryEntries() async -> [VocabularyEntry] {
        var entries: [VocabularyEntry] = []
        for lessonID in orderedLessonIDs {
            if let lesson = await loadLesson(lessonID) { entries.append(contentsOf: lesson.vocabulary) }
        }
        var unique: [VocabularyID: VocabularyEntry] = [:]
        entries.forEach { unique[$0.id] = $0 }
        return unique.values.sorted { $0.hanzi < $1.hanzi }
    }
}

private extension ProgressEventPayload {
    var profileValue: LearnerProfile? {
        if case .onboardingCompleted(let profile) = self { return profile }
        return nil
    }
}
