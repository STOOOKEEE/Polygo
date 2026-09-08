import Foundation
import PolygoCore
import PolygoSRS
import PolygoPersistence
import PolygoApple
#if canImport(Darwin)
import Darwin
#endif

@MainActor
public struct AppDependencies {
    public let content: any ContentStore
    public let progress: any ProgressStore
    public let exerciseEngine: any ExerciseEngine
    public let scheduler: any ReviewScheduler
    public let audio: any AudioService
    public let pronunciation: any SpeechPronunciationService
    public let handwriting: any HandwritingService
    public let clock: any PolygoClock

    public init(
        content: any ContentStore,
        progress: any ProgressStore,
        exerciseEngine: any ExerciseEngine = DefaultExerciseEngine(),
        scheduler: any ReviewScheduler,
        audio: any AudioService,
        handwriting: any HandwritingService,
        pronunciation: any SpeechPronunciationService = UnconfiguredSpeechPronunciationService(),
        clock: any PolygoClock = SystemPolygoClock()
    ) {
        self.content = content
        self.progress = progress
        self.exerciseEngine = exerciseEngine
        self.scheduler = scheduler
        self.audio = audio
        self.pronunciation = pronunciation
        self.handwriting = handwriting
        self.clock = clock
    }

    public static func live() -> AppDependencies {
        let fileManager = FileManager.default
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        let root = applicationSupport.appendingPathComponent("Polygo", isDirectory: true)
        let contentRoot = Bundle.main.resourceURL?.appendingPathComponent("Content", isDirectory: true)
            ?? URL(fileURLWithPath: "/missing-syllune-content", isDirectory: true)
#if DEBUG
        installDebugProgressFixtureIfRequested(root: root)
#endif
        let content = JSONContentStore(rootURL: contentRoot)
        let progress = JSONFileProgressStore(rootURL: root, reducer: DefaultProgressReducer())
        // Handwriting captures are local learning data. Keep the service
        // scoped to the app's dependency graph so a lesson can leave and
        // re-enter without losing its capture, while writing them under the
        // same application-support root as the progress journal.
        let handwriting = LocalHandwritingService(
            storage: .directory(root.appendingPathComponent("drawings", isDirectory: true))
        )
        return AppDependencies(
            content: content,
            progress: progress,
            scheduler: SM2Scheduler(),
            audio: AppleAudioService(contentRootURL: contentRoot),
            handwriting: handwriting,
            pronunciation: UnconfiguredSpeechPronunciationService()
        )
    }

#if DEBUG
    /// Imports a JSONL journal from the UI-test launch environment before the
    /// AppModel starts its first reload. UI-test runners and the application
    /// have different sandboxes, so a runner-side file cannot seed the AUT.
    /// This hook is deliberately restricted to `ui-` profiles and never
    /// replaces an existing journal or snapshot.
    private static func installDebugProgressFixtureIfRequested(root: URL) {
        let key = "SYLLUNE_PROGRESS_FIXTURE_JSONL"
        guard let rawFixture = ProcessInfo.processInfo.environment[key], !rawFixture.isEmpty else { return }

        let profileRaw = UserDefaults.standard.string(forKey: "syllune.profile.id") ?? ""
        guard profileRaw.hasPrefix("ui-"), let profileID = ProfileID(rawValue: profileRaw) else { return }
        let fileManager = FileManager.default
        let profileDirectory = root
            .appendingPathComponent("profiles", isDirectory: true)
            .appendingPathComponent(profileID.rawValue, isDirectory: true)
        let journalURL = profileDirectory.appendingPathComponent("events.jsonl", isDirectory: false)
        let snapshotURL = profileDirectory.appendingPathComponent("snapshot.json", isDirectory: false)
        let outboxURL = profileDirectory.appendingPathComponent("outbox.json", isDirectory: false)

        // A relaunch must exercise the persisted journal. A cache or outbox
        // without its journal is also left untouched so a fixture cannot
        // overwrite a partial real profile.
        guard !fileManager.fileExists(atPath: journalURL.path),
              !fileManager.fileExists(atPath: snapshotURL.path),
              !fileManager.fileExists(atPath: outboxURL.path) else { return }

        let decoder = JSONDecoder()
        var events: [ProgressEvent] = []
        var eventIDs = Set<EventID>()
        for (lineIndex, line) in rawFixture.components(separatedBy: .newlines).enumerated() {
            guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            guard let data = line.data(using: .utf8),
                  let event = try? decoder.decode(ProgressEvent.self, from: data),
                  event.schemaVersion == 1,
                  event.profileID == profileID,
                  event.lamport > 0,
                  eventIDs.insert(event.eventID).inserted else {
                assertionFailure("Invalid \(key) at JSONL line \(lineIndex + 1) for profile \(profileID.rawValue)")
                return
            }
            events.append(event)
        }
        guard !events.isEmpty else {
            assertionFailure("\(key) must contain at least one event")
            return
        }
        guard events.contains(where: { event in
            if case .onboardingCompleted(let profile) = event.payload { return profile.id == profileID }
            return false
        }) else {
            assertionFailure("\(key) must contain onboardingCompleted for profile \(profileID.rawValue)")
            return
        }

        do {
            try fileManager.createDirectory(at: profileDirectory, withIntermediateDirectories: true)
#if canImport(Darwin)
            let descriptor = open(journalURL.path, O_WRONLY | O_CREAT | O_EXCL, S_IRUSR | S_IWUSR)
            guard descriptor >= 0 else {
                // Another process may have installed the fixture or created
                // the real journal between the guard above and this write.
                if errno == EEXIST { return }
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
            let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
            do {
                try handle.write(contentsOf: Data(rawFixture.utf8))
                try handle.close()
            } catch {
                try? handle.close()
                try? fileManager.removeItem(at: journalURL)
                throw error
            }
#else
            guard !fileManager.fileExists(atPath: journalURL.path) else { return }
            try Data(rawFixture.utf8).write(to: journalURL, options: [.atomic])
#endif
        } catch {
            assertionFailure("Could not install \(key): \(error.localizedDescription)")
        }
    }
#endif
}

public enum SylluneServiceError: Error, LocalizedError, Sendable {
    case unavailable
    public var errorDescription: String? { "Ce service est indisponible sur cet appareil." }
}

public struct UnavailableHandwritingService: HandwritingService, Sendable {
    public init() {}
    public func recognize(_ capture: DrawingCapture, target: HandwritingExercise) async -> HandwritingRecognition { .unsupported }
    public func persist(_ capture: DrawingCapture) async throws -> DrawingID { throw SylluneServiceError.unavailable }
    public func delete(drawingID: DrawingID) async throws {}
}
