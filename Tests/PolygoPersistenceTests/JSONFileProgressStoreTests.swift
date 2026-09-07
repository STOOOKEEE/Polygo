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
