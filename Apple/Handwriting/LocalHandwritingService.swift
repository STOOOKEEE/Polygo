import Foundation
import PolygoCore

public enum HandwritingStorage: Sendable {
    /// Keeps captures only for the lifetime of this service instance. This is
    /// the default so a learner's strokes are not silently retained on disk.
    case memory
    /// Stores one JSON capture per drawing in the caller-provided directory.
    /// The caller owns the directory and decides how long drawings are kept.
    case directory(URL)
}

public enum HandwritingPersistenceError: Error, LocalizedError, Sendable, Equatable {
    case emptyDrawing
    case invalidDrawingID
    case unableToCreateDirectory(String)
    case unableToWrite(String)

    public var errorDescription: String? {
        switch self {
        case .emptyDrawing:
            return "Le tracé est vide."
        case .invalidDrawingID:
            return "L’identifiant du dessin est invalide."
        case .unableToCreateDirectory(let reason):
            return "Le dossier local des dessins n’a pas pu être créé : \(reason)"
        case .unableToWrite(let reason):
            return "Le dessin n’a pas pu être enregistré localement : \(reason)"
        }
    }
}

/// Local implementation for the handwriting contract.
///
/// The service intentionally returns `.unsupported` from `recognize`: the
/// point capture and geometry check do not claim to recognize arbitrary
/// handwriting. Persistence is injectable so the app can use memory for a
/// privacy-first session or an explicit application-support directory when it
/// needs a drawing to survive a view transition.
public actor LocalHandwritingService: HandwritingService {
    public static let shared = LocalHandwritingService()

    public let storage: HandwritingStorage
    private var captures: [DrawingID: DrawingCapture] = [:]
    private let fileManager: FileManager

    public init(storage: HandwritingStorage = .memory, fileManager: FileManager = .default) {
        self.storage = storage
        self.fileManager = fileManager
    }

    public func recognize(
        _ capture: DrawingCapture,
        target: HandwritingExercise
    ) async -> HandwritingRecognition {
        // Geometry is evaluated by HandwritingGeometryValidator, where the
        // guide is known. No general OCR or guessed character is returned.
        .unsupported
    }

    @discardableResult
    public func persist(_ capture: DrawingCapture) async throws -> DrawingID {
        guard !capture.drawingID.rawValue.isEmpty else {
            throw HandwritingPersistenceError.invalidDrawingID
        }
        guard capture.strokeCount > 0, !capture.dataRepresentation.isEmpty else {
            throw HandwritingPersistenceError.emptyDrawing
        }

        switch storage {
        case .memory:
            captures[capture.drawingID] = capture
        case .directory(let directory):
            do {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                throw HandwritingPersistenceError.unableToCreateDirectory(error.localizedDescription)
            }
            do {
                let url = fileURL(for: capture.drawingID, in: directory)
                try captureData(capture).write(to: url, options: .atomic)
            } catch let error as HandwritingPersistenceError {
                throw error
            } catch {
                throw HandwritingPersistenceError.unableToWrite(error.localizedDescription)
            }
        }
        return capture.drawingID
    }

    public func delete(drawingID: DrawingID) async throws {
        captures.removeValue(forKey: drawingID)
        guard case .directory(let directory) = storage else { return }
        let url = fileURL(for: drawingID, in: directory)
        do {
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
        } catch {
            throw HandwritingPersistenceError.unableToWrite(error.localizedDescription)
        }
    }

    /// Useful for an integration that wants to restore a capture after a
    /// process restart. The default memory policy naturally returns nil after
    /// the service is recreated.
    public func capture(drawingID: DrawingID) async -> DrawingCapture? {
        if let capture = captures[drawingID] { return capture }
        guard case .directory(let directory) = storage else { return nil }
        let url = fileURL(for: drawingID, in: directory)
        guard let data = try? Data(contentsOf: url),
              let capture = try? JSONDecoder().decode(DrawingCapture.self, from: data) else {
            return nil
        }
        captures[drawingID] = capture
        return capture
    }

    private func fileURL(for drawingID: DrawingID, in directory: URL) -> URL {
        directory.appendingPathComponent("\(drawingID.rawValue).drawing.json", isDirectory: false)
    }

    private func captureData(_ capture: DrawingCapture) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        do {
            return try encoder.encode(capture)
        } catch {
            throw HandwritingPersistenceError.unableToWrite(error.localizedDescription)
        }
    }
}
