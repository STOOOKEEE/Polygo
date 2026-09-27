import Foundation
import XCTest
@testable import PolygoCore
@testable import PolygoSRS
@testable import PolygoPersistence

final class JSONFileProgressStoreTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func id(_ raw: String) -> ProfileID { ProfileID(rawValue: raw)! }
    private func device(_ raw: String) -> DeviceID { DeviceID(rawValue: raw)! }
    private func event(_ raw: String, profile: ProfileID, device: DeviceID, lamport: UInt64, payload: ProgressEventPayload) -> ProgressEvent {
        ProgressEvent(eventID: EventID(rawValue: raw)!, profileID: profile, deviceID: device, lamport: lamport, occurredAt: now, payload: payload)
    }

    private func profile(_ id: ProfileID) -> LearnerProfile {
        LearnerProfile(id: id, selectedCourseID: CourseID(rawValue: "mandarin-starter")!, createdAt: now)
    }

    private func makeStore(_ directory: URL) -> JSONFileProgressStore {
        JSONFileProgressStore(rootURL: directory, reducer: DefaultProgressReducer())
    }

    func testAppendReloadAndOutboxAcknowledgement() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let profileID = id("profile-persistence")
        let store = makeStore(directory)
        let onboarding = event("onboarding", profile: profileID, device: device("phone"), lamport: 1, payload: .onboardingCompleted(profile: profile(profileID)))
        let lesson = LessonID(rawValue: "lesson-01")!
        let started = event("lesson-start", profile: profileID, device: device("phone"), lamport: 2, payload: .lessonStarted(lessonID: lesson, at: now))

        let first = try await store.append(onboarding)
        XCTAssertEqual(first.profile?.id, profileID)
        _ = try await store.append(started)
        let pendingAfterAppend = try await store.pendingEvents(profileID: profileID, limit: 10)
        XCTAssertEqual(pendingAfterAppend.count, 2)

        try await store.markSynced(eventIDs: [onboarding.eventID], profileID: profileID)
        let pendingAfterAck = try await store.pendingEvents(profileID: profileID, limit: 10)
        XCTAssertEqual(pendingAfterAck.map(\.eventID), [started.eventID])

        let reloaded = makeStore(directory)
        let snapshot = try await reloaded.load(profileID: profileID)
        XCTAssertEqual(snapshot.profile?.id, profileID)
        XCTAssertEqual(snapshot.lessonProgress[lesson]?.lastOpenedAt, now)
        let pendingAfterReload = try await reloaded.pendingEvents(profileID: profileID, limit: 10)
        XCTAssertEqual(pendingAfterReload.map(\.eventID), [started.eventID])
    }

    func testLamportDeviceEventOrderMakesReviewReplayIndependentOfArrival() async throws {
        let firstDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let secondDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let profileID = id("profile-order")
        let cardID = CardID(rawValue: "card-order")!
        let phone = device("phone")
        let tablet = device("tablet")
        let onboarding = event("onboarding", profile: profileID, device: phone, lamport: 1, payload: .onboardingCompleted(profile: profile(profileID)))
        let added = event("card-added", profile: profileID, device: phone, lamport: 2, payload: .flashcardAdded(cardID: cardID, at: now))
        let reviewA = event("review-a", profile: profileID, device: tablet, lamport: 3, payload: .flashcardReviewed(cardID: cardID, rating: .good, at: now.addingTimeInterval(1)))
        let reviewB = event("review-b", profile: profileID, device: phone, lamport: 3, payload: .flashcardReviewed(cardID: cardID, rating: .easy, at: now.addingTimeInterval(2)))

        let first = makeStore(firstDirectory)
        for value in [onboarding, added, reviewA, reviewB] { _ = try await first.append(value) }
        let second = makeStore(secondDirectory)
        for value in [reviewB, reviewA, added, onboarding] { _ = try await second.append(value) }

        let firstSnapshot = try await first.load(profileID: profileID)
        let secondSnapshot = try await second.load(profileID: profileID)
        XCTAssertEqual(firstSnapshot, secondSnapshot)
        let firstDeck = try await first.reviewDeck(profileID: profileID)
        let secondDeck = try await second.reviewDeck(profileID: profileID)
        XCTAssertEqual(firstDeck, secondDeck)
    }

    func testDuplicateIDWithDifferentPayloadIsRejected() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let profileID = id("profile-duplicate")
        let store = makeStore(directory)
        let original = event("same-id", profile: profileID, device: device("phone"), lamport: 1, payload: .onboardingCompleted(profile: profile(profileID)))
        _ = try await store.append(original)
        let changed = ProgressEvent(eventID: original.eventID, profileID: profileID, deviceID: device("phone"), lamport: 1, occurredAt: now.addingTimeInterval(1), payload: original.payload)

        do {
            _ = try await store.append(changed)
            XCTFail("A reused event ID must be rejected")
        } catch let error as ProgressStoreError {
            XCTAssertEqual(error, .duplicateEvent(original.eventID))
        }
    }

    func testUnterminatedFinalLineIsQuarantinedAndPreviousEventsSurvive() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let profileID = id("profile-partial")
        let store = makeStore(directory)
        let onboarding = event("onboarding", profile: profileID, device: device("phone"), lamport: 1, payload: .onboardingCompleted(profile: profile(profileID)))
        _ = try await store.append(onboarding)

        let journal = directory.appendingPathComponent("profiles/\(profileID.rawValue)/events.jsonl")
        let valid = try Data(contentsOf: journal)
        var corrupted = valid
        corrupted.append(contentsOf: Data("{\"eventID\":\"partial".utf8))
        try corrupted.write(to: journal, options: [.atomic])

        let reloaded = makeStore(directory)
        let snapshot = try await reloaded.load(profileID: profileID)
        XCTAssertEqual(snapshot.profile?.id, profileID)
        let recoveries = try FileManager.default.contentsOfDirectory(at: journal.deletingLastPathComponent(), includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("events.jsonl.partial.") }
        XCTAssertEqual(recoveries.count, 1)
    }

    func testTerminatedCorruptLineFailsLoudly() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let profileID = id("profile-corrupt")
        let path = directory.appendingPathComponent("profiles/\(profileID.rawValue)/events.jsonl")
        try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{not-json}\n".utf8).write(to: path)

        do {
            _ = try await makeStore(directory).load(profileID: profileID)
            XCTFail("A committed malformed line must not be ignored")
        } catch let error as ProgressStoreError {
            XCTAssertEqual(error, .corruptedJournal(line: 1))
        }
    }

    func testReviewDeckPersistsHistoryAndSuspension() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let profileID = id("profile-deck")
        let cardID = CardID(rawValue: "card-deck")!
        let store = makeStore(directory)
        let values: [ProgressEvent] = [
            event("onboarding", profile: profileID, device: device("phone"), lamport: 1, payload: .onboardingCompleted(profile: profile(profileID))),
            event("add", profile: profileID, device: device("phone"), lamport: 2, payload: .flashcardAdded(cardID: cardID, at: now)),
            event("review", profile: profileID, device: device("phone"), lamport: 3, payload: .flashcardReviewed(cardID: cardID, rating: .good, at: now)),
            event("suspend", profile: profileID, device: device("phone"), lamport: 4, payload: .flashcardSuspended(cardID: cardID, suspended: true, at: now))
        ]
        for value in values { _ = try await store.append(value) }
        let deck = try await store.reviewDeck(profileID: profileID)
        XCTAssertEqual(deck.history[cardID]?.count, 1)
        XCTAssertTrue(deck.suspendedCardIDs.contains(cardID))
        XCTAssertEqual(deck.state(for: cardID)?.repetition ?? -1, 1)
    }

    func testFilesystemFailureIsReportedWithoutChangingTheEvent() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("not a directory".utf8).write(to: root, options: [.atomic])
        let profileID = id("profile-io")
        let store = makeStore(root)
        let value = event("onboarding", profile: profileID, device: device("phone"), lamport: 1, payload: .onboardingCompleted(profile: profile(profileID)))

        do {
            _ = try await store.append(value)
            XCTFail("A file used as the root directory must report I/O failure")
        } catch let error as ProgressStoreError {
            if case .ioFailure(_) = error { } else { XCTFail("Unexpected persistence error: \(error)") }
        }
    }

    func testFirstCompletionProjectionReplaysInOrderAndIsProfileScoped() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let firstProfile = id("profile-reward-first")
        let secondProfile = id("profile-reward-second")
        let retiredLesson = LessonID(rawValue: "lesson-retired-from-catalog")!
        let anotherLesson = LessonID(rawValue: "lesson-another-reward")!
        let store = makeStore(directory)
        _ = try await store.append(event(
            "reward-first-onboarding",
            profile: firstProfile,
            device: device("phone"),
            lamport: 1,
            payload: .onboardingCompleted(profile: profile(firstProfile))
        ))

        let earlier = event(
            "reward-earlier",
            profile: firstProfile,
            device: device("phone"),
            lamport: 2,
            payload: .lessonCompleted(lessonID: retiredLesson, at: now)
        )
        let later = event(
            "reward-later",
            profile: firstProfile,
            device: device("phone"),
            lamport: 3,
            payload: .lessonCompleted(lessonID: retiredLesson, at: now.addingTimeInterval(10))
        )
        _ = try await store.append(later)
        let reordered = try await store.append(earlier)
        XCTAssertEqual(reordered.firstCompletionEventIDs?[retiredLesson], earlier.eventID)
        _ = try await store.append(later)

        let anotherCompletion = event(
            "reward-another",
            profile: firstProfile,
            device: device("phone"),
            lamport: 4,
            payload: .lessonCompleted(lessonID: anotherLesson, at: now.addingTimeInterval(20))
        )
        _ = try await store.append(anotherCompletion)
        _ = try await store.append(event(
            "reward-second-onboarding",
            profile: secondProfile,
            device: device("tablet"),
            lamport: 1,
            payload: .onboardingCompleted(profile: profile(secondProfile))
        ))
        let otherLesson = LessonID(rawValue: "lesson-other-profile")!
        let otherCompletion = event(
            "reward-other-profile",
            profile: secondProfile,
            device: device("tablet"),
            lamport: 2,
            payload: .lessonCompleted(lessonID: otherLesson, at: now)
        )
        _ = try await store.append(otherCompletion)

        let firstReload = try await makeStore(directory).load(profileID: firstProfile)
        XCTAssertEqual(firstReload.firstCompletionEventIDs, [
            retiredLesson: earlier.eventID,
            anotherLesson: anotherCompletion.eventID
        ])
        let secondReload = try await makeStore(directory).load(profileID: secondProfile)
        XCTAssertEqual(secondReload.firstCompletionEventIDs, [otherLesson: otherCompletion.eventID])
        let journal = try await makeStore(directory).events(profileID: firstProfile)
        let retiredCompletions = journal.compactMap { value -> EventID? in
            guard case .lessonCompleted(let lessonID, _) = value.payload, lessonID == retiredLesson else { return nil }
            return value.eventID
        }
        XCTAssertEqual(retiredCompletions, [earlier.eventID, later.eventID])
    }

    func testLegacyCacheWithCompleteJournalRebuildsFirstCompletionProjection() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let profileID = id("profile-legacy-cache-journal")
        let lessonID = LessonID(rawValue: "lesson-legacy-cache")!
        let store = makeStore(directory)
        _ = try await store.append(event(
            "legacy-journal-onboarding",
            profile: profileID,
            device: device("phone"),
            lamport: 1,
            payload: .onboardingCompleted(profile: profile(profileID))
        ))
        let completion = event(
            "legacy-journal-completion",
            profile: profileID,
            device: device("phone"),
            lamport: 2,
            payload: .lessonCompleted(lessonID: lessonID, at: now)
        )
        _ = try await store.append(completion)

        let cacheURL = directory.appendingPathComponent("profiles/\(profileID.rawValue)/snapshot.json")
        var legacyCache = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: Data(contentsOf: cacheURL)) as? [String: Any]
        )
        legacyCache.removeValue(forKey: "firstCompletionEventIDs")
        try JSONSerialization.data(withJSONObject: legacyCache).write(to: cacheURL, options: [.atomic])

        let reloaded = try await makeStore(directory).load(profileID: profileID)
        XCTAssertEqual(reloaded.firstCompletionEventIDs, [lessonID: completion.eventID])
    }

    func testLegacyEmptyCacheWithEmptyJournalRebuildsKnownEmptyHistory() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let profileID = id("profile-empty-legacy-cache-journal")
        let profileDirectory = directory.appendingPathComponent("profiles/\(profileID.rawValue)")
        try FileManager.default.createDirectory(at: profileDirectory, withIntermediateDirectories: true)
        let cacheURL = profileDirectory.appendingPathComponent("snapshot.json")
        var legacyCache = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(ProgressSnapshot.empty(now: now))) as? [String: Any]
        )
        legacyCache.removeValue(forKey: "firstCompletionEventIDs")
        try JSONSerialization.data(withJSONObject: legacyCache).write(to: cacheURL)
        try Data().write(to: profileDirectory.appendingPathComponent("events.jsonl"))

        let reloaded = try await makeStore(directory).load(profileID: profileID)
        XCTAssertEqual(reloaded.firstCompletionEventIDs, [:])
    }

    func testLegacyEmptyCacheWithInterruptedFirstLineRebuildsKnownEmptyHistory() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let profileID = id("profile-empty-legacy-cache-partial-journal")
        let profileDirectory = directory.appendingPathComponent("profiles/\(profileID.rawValue)")
        try FileManager.default.createDirectory(at: profileDirectory, withIntermediateDirectories: true)
        let cacheURL = profileDirectory.appendingPathComponent("snapshot.json")
        var legacyCache = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(ProgressSnapshot.empty(now: now))) as? [String: Any]
        )
        legacyCache.removeValue(forKey: "firstCompletionEventIDs")
        try JSONSerialization.data(withJSONObject: legacyCache).write(to: cacheURL)
        let journalURL = profileDirectory.appendingPathComponent("events.jsonl")
        try Data(#"{"eventID":"interrupted"#.utf8).write(to: journalURL)

        let reloaded = try await makeStore(directory).load(profileID: profileID)
        XCTAssertEqual(reloaded.firstCompletionEventIDs, [:])
        let recoveries = try FileManager.default.contentsOfDirectory(at: profileDirectory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("events.jsonl.partial.") }
        XCTAssertEqual(recoveries.count, 1)
        XCTAssertEqual(try Data(contentsOf: journalURL), Data())
    }

    func testEmptyLegacyCacheWithoutJournalDoesNotBecomeKnownZeroHistory() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let profileID = id("profile-empty-legacy-cache")
        let profileDirectory = directory.appendingPathComponent("profiles/\(profileID.rawValue)")
        try FileManager.default.createDirectory(at: profileDirectory, withIntermediateDirectories: true)
        var legacyCache = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(ProgressSnapshot.empty(now: now))) as? [String: Any]
        )
        legacyCache.removeValue(forKey: "firstCompletionEventIDs")
        try JSONSerialization.data(withJSONObject: legacyCache).write(
            to: profileDirectory.appendingPathComponent("snapshot.json")
        )

        let reloaded = try await makeStore(directory).load(profileID: profileID)
        XCTAssertNil(reloaded.firstCompletionEventIDs)
        do {
            _ = try await makeStore(directory).append(event(
                "append-to-empty-legacy-cache",
                profile: profileID,
                device: device("phone"),
                lamport: 1,
                payload: .onboardingCompleted(profile: profile(profileID))
            ))
            XCTFail("An empty old snapshot without its journal must not imply known zero history")
        } catch let error as ProgressStoreError {
            if case .ioFailure(_) = error { } else { XCTFail("Unexpected error: \(error)") }
        }
    }

    func testLegacyCacheWithoutJournalKeepsUnknownHistoryAndRejectsAppend() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let profileID = id("profile-legacy-without-journal")
        let lessonID = LessonID(rawValue: "lesson-cached-only")!
        let store = makeStore(directory)
        _ = try await store.append(event(
            "legacy-cache-onboarding",
            profile: profileID,
            device: device("phone"),
            lamport: 1,
            payload: .onboardingCompleted(profile: profile(profileID))
        ))
        _ = try await store.append(event(
            "legacy-cache-completion",
            profile: profileID,
            device: device("phone"),
            lamport: 2,
            payload: .lessonCompleted(lessonID: lessonID, at: now)
        ))
        let profileDirectory = directory.appendingPathComponent("profiles/\(profileID.rawValue)")
        try FileManager.default.removeItem(at: profileDirectory.appendingPathComponent("events.jsonl"))
        let cacheURL = profileDirectory.appendingPathComponent("snapshot.json")
        var legacyCache = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: Data(contentsOf: cacheURL)) as? [String: Any]
        )
        legacyCache.removeValue(forKey: "firstCompletionEventIDs")
        try JSONSerialization.data(withJSONObject: legacyCache).write(to: cacheURL, options: [.atomic])

        let reloaded = try await makeStore(directory).load(profileID: profileID)
        XCTAssertNil(reloaded.firstCompletionEventIDs)
        XCTAssertEqual(reloaded.lessonProgress[lessonID]?.completedAt, now)

        do {
            _ = try await makeStore(directory).append(event(
                "append-after-legacy-journal-loss",
                profile: profileID,
                device: device("phone"),
                lamport: 3,
                payload: .lessonCompleted(lessonID: lessonID, at: now.addingTimeInterval(10))
            ))
            XCTFail("A non-empty snapshot without its journal must remain append-protected")
        } catch let error as ProgressStoreError {
            if case .ioFailure(_) = error { } else { XCTFail("Unexpected error: \(error)") }
        }
    }

    func testJournalCompletionSurvivesSnapshotWriteFailureAndExactRetry() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let profileID = id("profile-cache-write-failure")
        let lessonID = LessonID(rawValue: "lesson-cache-write-failure")!
        _ = try await makeStore(directory).append(event(
            "cache-failure-onboarding",
            profile: profileID,
            device: device("phone"),
            lamport: 1,
            payload: .onboardingCompleted(profile: profile(profileID))
        ))
        let completion = event(
            "cache-failure-completion",
            profile: profileID,
            device: device("phone"),
            lamport: 2,
            payload: .lessonCompleted(lessonID: lessonID, at: now)
        )
        let failingStore = JSONFileProgressStore(
            rootURL: directory,
            reducer: DefaultProgressReducer(),
            fileManager: FailSecondProfileDirectoryCreationFileManager(profileDirectoryName: profileID.rawValue)
        )

        do {
            _ = try await failingStore.append(completion)
            XCTFail("The injected snapshot write failure must be reported")
        } catch let error as ProgressStoreError {
            if case .ioFailure(_) = error { } else { XCTFail("Unexpected error: \(error)") }
        }
        let durableEvents = try await makeStore(directory).events(profileID: profileID)
        XCTAssertTrue(durableEvents.contains(completion))

        let repaired = try await failingStore.append(completion)
        XCTAssertEqual(repaired.firstCompletionEventIDs?[lessonID], completion.eventID)
        let persistedEvents = try await makeStore(directory).events(profileID: profileID)
        let completionEvents = persistedEvents.filter {
            if case .lessonCompleted(let id, _) = $0.payload { return id == lessonID }
            return false
        }
        XCTAssertEqual(completionEvents.map(\.eventID), [completion.eventID])
    }

    func testJournalCardAdditionSurvivesSnapshotWriteFailureAndExactRetry() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let profileID = id("profile-card-cache-failure")
        let lessonID = LessonID(rawValue: "lesson-card-cache-failure")!
        let cardID = CardID(rawValue: "card-cache-failure")!
        let store = makeStore(directory)
        _ = try await store.append(event(
            "card-cache-onboarding",
            profile: profileID,
            device: device("phone"),
            lamport: 1,
            payload: .onboardingCompleted(profile: profile(profileID))
        ))
        _ = try await store.append(event(
            "card-cache-completion",
            profile: profileID,
            device: device("phone"),
            lamport: 2,
            payload: .lessonCompleted(lessonID: lessonID, at: now)
        ))
        let cardAddition = event(
            "card-cache-addition",
            profile: profileID,
            device: device("phone"),
            lamport: 3,
            payload: .flashcardAdded(cardID: cardID, at: now)
        )
        let failingStore = JSONFileProgressStore(
            rootURL: directory,
            reducer: DefaultProgressReducer(),
            fileManager: FailSecondProfileDirectoryCreationFileManager(profileDirectoryName: profileID.rawValue)
        )

        do {
            _ = try await failingStore.append(cardAddition)
            XCTFail("The injected card snapshot write failure must be reported")
        } catch let error as ProgressStoreError {
            if case .ioFailure(_) = error { } else { XCTFail("Unexpected error: \(error)") }
        }
        let durableEvents = try await makeStore(directory).events(profileID: profileID)
        XCTAssertTrue(durableEvents.contains(cardAddition))

        let repaired = try await failingStore.append(cardAddition)
        XCTAssertEqual(repaired.reviewStates[cardID]?.dueAt, now)
        let persistedEvents = try await makeStore(directory).events(profileID: profileID)
        let cardEvents = persistedEvents.filter {
            if case .flashcardAdded(let id, _) = $0.payload { return id == cardID }
            return false
        }
        XCTAssertEqual(cardEvents.map(\.eventID), [cardAddition.eventID])
    }
}

private final class FailSecondProfileDirectoryCreationFileManager: FileManager {
    private let profileDirectoryName: String
    private let lock = NSLock()
    private var profileDirectoryCreations = 0

    init(profileDirectoryName: String) {
        self.profileDirectoryName = profileDirectoryName
        super.init()
    }

    override func createDirectory(
        at url: URL,
        withIntermediateDirectories createIntermediates: Bool,
        attributes: [FileAttributeKey: Any]? = nil
    ) throws {
        let shouldFail: Bool
        if url.lastPathComponent == profileDirectoryName {
            lock.lock()
            profileDirectoryCreations += 1
            shouldFail = profileDirectoryCreations == 2
            lock.unlock()
        } else {
            shouldFail = false
        }
        if shouldFail {
            throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.Code.fileWriteNoPermission.rawValue)
        }
        try super.createDirectory(
            at: url,
            withIntermediateDirectories: createIntermediates,
            attributes: attributes
        )
    }
}

private actor InMemorySyncClient: CloudSyncClient {
    private var stored: [EventID: ProgressEvent] = [:]

    func push(_ events: [ProgressEvent]) async throws -> SyncPushResult {
        var accepted: [EventID] = []
        var duplicates: [EventID] = []
        for event in events {
            if let old = stored[event.eventID] {
                if old == event {
                    duplicates.append(event.eventID)
                } else {
                    throw ProgressStoreError.duplicateEvent(event.eventID)
                }
            } else {
                stored[event.eventID] = event
                accepted.append(event.eventID)
            }
        }
        return SyncPushResult(accepted: accepted, duplicates: duplicates)
    }

    func pull(after cursor: SyncCursor?) async throws -> SyncPullResult {
        let offset = cursor.flatMap { Int(String(data: $0.opaqueValue, encoding: .utf8) ?? "") } ?? 0
        let events = stored.values.sorted {
            if $0.lamport != $1.lamport { return $0.lamport < $1.lamport }
            if $0.deviceID.rawValue != $1.deviceID.rawValue { return $0.deviceID.rawValue < $1.deviceID.rawValue }
            return $0.eventID.rawValue < $1.eventID.rawValue
        }
        let page = Array(events.dropFirst(offset))
        let next = offset + page.count
        return SyncPullResult(events: page, cursor: SyncCursor(opaqueValue: Data(String(next).utf8)))
    }
}

final class SyncCoordinatorTests: XCTestCase {
    func testPushPullAndAcknowledgementsAreRetrySafe() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let profileID = ProfileID(rawValue: "profile-sync")!
        let store = JSONFileProgressStore(rootURL: directory, reducer: DefaultProgressReducer())
        let profile = LearnerProfile(id: profileID, selectedCourseID: CourseID(rawValue: "mandarin-starter")!, createdAt: Date(timeIntervalSince1970: 1_700_000_000))
        let event = ProgressEvent(profileID: profileID, deviceID: DeviceID(rawValue: "phone")!, lamport: 1, occurredAt: profile.createdAt, payload: .onboardingCompleted(profile: profile))
        _ = try await store.append(event)

        let client = InMemorySyncClient()
        let coordinator = SyncCoordinator(store: store, client: client, profileID: profileID, batchSize: 1)
        let report = try await coordinator.sync()
        XCTAssertEqual(report.pushedEventCount, 1)
        XCTAssertEqual(report.pulledEventCount, 1)
        let pending = try await store.pendingEvents(profileID: profileID, limit: 10)
        XCTAssertTrue(pending.isEmpty)

        // The second run sees an empty outbox and an already-consumed cursor.
        let secondReport = try await coordinator.sync()
        XCTAssertEqual(secondReport.pushedEventCount, 0)
        XCTAssertEqual(secondReport.pulledEventCount, 0)
    }
}
