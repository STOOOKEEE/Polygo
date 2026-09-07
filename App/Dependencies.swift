import Foundation
import PolygoCore
import PolygoSRS
import PolygoPersistence
import PolygoApple

@MainActor
public struct AppDependencies {
    public let content: any ContentStore
    public let progress: any ProgressStore
    public let exerciseEngine: any ExerciseEngine
    public let scheduler: any ReviewScheduler
    public let audio: any AudioService
    public let handwriting: any HandwritingService
    public let clock: any PolygoClock

    public init(
        content: any ContentStore,
        progress: any ProgressStore,
        exerciseEngine: any ExerciseEngine = DefaultExerciseEngine(),
        scheduler: any ReviewScheduler,
        audio: any AudioService,
        handwriting: any HandwritingService,
        clock: any PolygoClock = SystemPolygoClock()
    ) {
        self.content = content
        self.progress = progress
        self.exerciseEngine = exerciseEngine
        self.scheduler = scheduler
        self.audio = audio
        self.handwriting = handwriting
        self.clock = clock
    }

    public static func live() -> AppDependencies {
        let fileManager = FileManager.default
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        let root = applicationSupport.appendingPathComponent("Polygo", isDirectory: true)
        let contentRoot = Bundle.main.resourceURL?.appendingPathComponent("Content", isDirectory: true)
            ?? URL(fileURLWithPath: "/missing-syllune-content", isDirectory: true)
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
            handwriting: handwriting
        )
    }
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
