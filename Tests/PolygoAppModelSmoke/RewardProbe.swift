import Foundation
import Combine
import PolygoCore
import PolygoSRS
import PolygoPersistence
import PolygoApple
import PolygoMacApp

// Native regression probe: link the actual Debug app module, not copied app types.
private struct ProbeFailure: Error, CustomStringConvertible {
    let description: String
}

private func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw ProbeFailure(description: message) }
}

// Same injection boundary as the existing persistence test: all other filesystem
// operations, JSON serialization, reducer and AppModel behavior remain real.
private final class FaultFileManager: FileManager, @unchecked Sendable {
    private let profileName: String
    private let lock = NSLock()
    private var remaining: Int?

    init(profileName: String) {
        self.profileName = profileName
        super.init()
    }

    func arm(_ profileDirectoryCreation: Int) {
        lock.lock()
        remaining = profileDirectoryCreation
        lock.unlock()
    }

    override func createDirectory(
        at url: URL,
        withIntermediateDirectories createIntermediates: Bool,
        attributes: [FileAttributeKey: Any]? = nil
    ) throws {
        lock.lock()
        var fail = false
        if url.lastPathComponent == profileName, let count = remaining {
            fail = count == 1
            remaining = fail ? nil : count - 1
        }
        lock.unlock()
        if fail {
            throw NSError(domain: NSCocoaErrorDomain,
                          code: CocoaError.Code.fileWriteNoPermission.rawValue)
        }
        try super.createDirectory(at: url, withIntermediateDirectories: createIntermediates,
                                  attributes: attributes)
    }
}

// Observation only: preserve and forward every call to the actual on-disk store.
private actor ObservedStore: ProgressStore {
    let real: JSONFileProgressStore
    private(set) var attempts: [ProgressEvent] = []

    init(real: JSONFileProgressStore) { self.real = real }
    func load(profileID: ProfileID) async throws -> ProgressSnapshot {
        try await real.load(profileID: profileID)
    }
    func append(_ event: ProgressEvent) async throws -> ProgressSnapshot {
        attempts.append(event)
        return try await real.append(event)
    }
    func pendingEvents(profileID: ProfileID, limit: Int) async throws -> [ProgressEvent] {
        try await real.pendingEvents(profileID: profileID, limit: limit)
    }
    func markSynced(eventIDs: [EventID], profileID: ProfileID) async throws {
        try await real.markSynced(eventIDs: eventIDs, profileID: profileID)
    }
}

@main
private struct RewardProbe {
    @MainActor
    static func ready(_ model: AppModel) async throws {
        for await loading in model.$isLoading.values {
            if !loading { break }
        }
        try require(model.index != nil && model.errorMessage == nil,
                    "Initial real content/store load failed: \(model.errorMessage ?? "missing index")")
    }

    static func completion(_ events: [ProgressEvent], lesson: LessonID) throws -> ProgressEvent {
        guard let result = events.last(where: {
            if case .lessonCompleted(let id, _) = $0.payload { return id == lesson }
            return false
        }) else { throw ProbeFailure(description: "No actual completion event found") }
        return result
    }

    @MainActor
    static func report(_ phase: String, model: AppModel, earned: Int? = nil,
                       event: ProgressEvent? = nil) throws {
        var row: [String: Any] = ["phase": phase, "profile": model.profileID.rawValue,
                                  "balance": model.coinBalance.map { $0 as Any } ?? NSNull(),
                                  "earned": earned.map { $0 as Any } ?? NSNull(),
                                  "error": model.errorMessage.map { $0 as Any } ?? NSNull()]
        if let event {
            row["eventID"] = event.eventID.rawValue
            row["lamport"] = event.lamport
            row["occurredAt"] = event.occurredAt.timeIntervalSince1970
        }
        print(String(decoding: try JSONSerialization.data(withJSONObject: row, options: [.sortedKeys]),
                     as: UTF8.self))
    }

    @MainActor
    static func verifyFreshCompletion(_ model: AppModel, real: JSONFileProgressStore,
                                      lesson: LessonID, previous: ProgressEvent,
                                      restart: ProgressEvent, firstID: EventID?) async throws -> ProgressEvent {
        let events = try await real.events(profileID: model.profileID)
        let current = try completion(events, lesson: lesson)
        try require(current.eventID != previous.eventID, "Obsolete completion EventID was reused")
        try require(current.lamport > restart.lamport, "Completion did not follow restart Lamport")
        guard case .lessonCompleted(_, let at) = current.payload else {
            throw ProbeFailure(description: "Unexpected completion payload")
        }
        try require(model.snapshot.lessonProgress[lesson]?.completedAt == at,
                    "completedAt is not the post-restart completion timestamp")
        try require(model.snapshot.firstCompletionEventIDs?[lesson] == (firstID ?? current.eventID),
                    "Historical first completion identity changed")
        try require(model.coinBalance == 10, "First historical lesson must remain worth exactly 10")
        return current
    }

    @MainActor
    static func runCase(_ name: String, contentRoot: URL, output: URL) async throws {
        let suite = "PolygoRewardProbe.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            throw ProbeFailure(description: "Cannot create isolated defaults")
        }
        defer { defaults.removePersistentDomain(forName: suite) }
        let profileRaw = "ui-reward-\(UUID().uuidString.lowercased())"
        defaults.set(profileRaw, forKey: "syllune.profile.id")
        defaults.set("today", forKey: "syllune.last.route")
        let files = FaultFileManager(profileName: profileRaw)
        let root = output.appendingPathComponent(name, isDirectory: true)
        let real = JSONFileProgressStore(rootURL: root, reducer: DefaultProgressReducer(), fileManager: files)
        let observed = ObservedStore(real: real)
        let dependencies = AppDependencies(
            content: JSONContentStore(rootURL: contentRoot), progress: observed,
            scheduler: SM2Scheduler(), audio: AppleAudioService(contentRootURL: contentRoot),
            handwriting: LocalHandwritingService(storage: .directory(root.appendingPathComponent("drawings")))
        )
        let model = AppModel(dependencies: dependencies, defaults: defaults)
        try await ready(model)
        try require(await model.completeOnboarding(displayName: "Probe", level: "beginner", minutes: 10,
                                                   reminderDays: []), "Onboarding append failed")
        let lesson = LessonID(rawValue: "lesson-01")!
        guard let document = await model.loadLesson(lesson), !document.cards.isEmpty else {
            throw ProbeFailure(description: "Real lesson-01 and its cards are required")
        }
        try require(model.coinBalance == 0, "Fresh profile must have known zero history")
        try report(name + ".initial", model: model)

        let previous: ProgressEvent
        let firstID: EventID?
        if name == "pre-journal" {
            files.arm(1)
            try require(await model.completeLesson(lesson) == nil, "Pre-journal fault was not surfaced")
            try require(model.errorMessage != nil && model.coinBalance == 0,
                        "Pre-journal failure must preserve zero balance and expose error")
            previous = try completion(await observed.attempts, lesson: lesson)
            let durable = try await real.events(profileID: model.profileID)
            try require(!durable.contains(where: { $0.eventID == previous.eventID }),
                        "Pre-journal completion unexpectedly became durable")
            try report(name + ".failed-before-journal", model: model, event: previous)
            try require(await model.updateDailyMinutes(12), "Intervening real event failed")
            firstID = nil
        } else {
            // H becomes durable; fail the first card journal write, before any successful award result.
            files.arm(3)
            try require(await model.completeLesson(lesson) == nil, "First-card fault was not surfaced")
            try require(model.errorMessage != nil && model.coinBalance == 10,
                        "Durable first completion must retain 10 while card error is visible")
            let historical = try completion(try await real.events(profileID: model.profileID), lesson: lesson)
            firstID = historical.eventID
            try report(name + ".historical-awaiting-card-retry", model: model, event: historical)
            try require(await model.restartLesson(lesson), "First restart failed")
            files.arm(2)
            try require(await model.completeLesson(lesson) == nil, "Recompletion cache fault was not surfaced")
            try require(model.errorMessage != nil, "Cache failure must remain visible")
            previous = try completion(try await real.events(profileID: model.profileID), lesson: lesson)
            try require(previous.eventID != historical.eventID, "Recompletion must have a fresh identity")
            try report(name + ".durable-recompletion-cache-failed", model: model, event: previous)
            // Intentionally the SAME AppModel. Recreating it would miss stale pending attempts.
            await model.reload()
            try require(model.errorMessage == nil && model.coinBalance == 10, "Same-instance reload failed")
            try require(model.snapshot.firstCompletionEventIDs?[lesson] == historical.eventID,
                        "Reload lost the first historical completion")
            try report(name + ".same-instance-reload", model: model)
        }

        try require(await model.restartLesson(lesson), "Post-failure restart was not acknowledged")
        guard let restart = await observed.attempts.last,
              case .lessonRestarted(let restartedID, _) = restart.payload, restartedID == lesson else {
            throw ProbeFailure(description: "Actual restart event missing")
        }
        try require(model.snapshot.lessonProgress[lesson]?.completedAt == nil,
                    "Restart did not clear current pedagogical completion")
        let result = await model.completeLesson(lesson)
        try require(result?.earnedCoins == 10, "Unconsumed legitimate first award must appear once")
        let current = try await verifyFreshCompletion(model, real: real, lesson: lesson,
                                                      previous: previous, restart: restart, firstID: firstID)
        if name == "pre-journal" {
            let durable = try await real.events(profileID: model.profileID)
            try require(!durable.contains(where: { $0.eventID == previous.eventID }),
                        "Failed pre-journal attempt was replayed after restart")
        }
        try report(name + ".post-restart-finalized", model: model, earned: result?.earnedCoins, event: current)
        let repeated = await model.completeLesson(lesson)
        try require(repeated?.earnedCoins == 0 && model.coinBalance == 10, "Same-session award duplicated")
        await model.reload()
        let afterReload = await model.completeLesson(lesson)
        try require(afterReload?.earnedCoins == 0 && model.coinBalance == 10, "Reload reannounced award")
        let reopened = AppModel(dependencies: dependencies, defaults: defaults)
        try await ready(reopened)
        let restored = await reopened.completeLesson(lesson)
        try require(restored?.earnedCoins == 0 && reopened.coinBalance == 10, "New model reannounced award")
        try report(name + ".new-model-no-reannouncement", model: reopened, earned: restored?.earnedCoins)
        let traces = try JSONEncoder().encode(await observed.attempts)
        try traces.write(to: output.appendingPathComponent(name + "-append-attempts.json"), options: .atomic)
    }

    @MainActor
    static func main() async throws {
        guard CommandLine.arguments.count == 3 else {
            throw ProbeFailure(description: "Usage: RewardProbe CONTENT_ROOT EVIDENCE_DIRECTORY")
        }
        let content = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try await runCase("pre-journal", contentRoot: content, output: output)
        try await runCase("durable-cache-reload", contentRoot: content, output: output)
        print("PASS AppModel reward fault probes: 2 sequences; real JSON journals retained")
    }
}
