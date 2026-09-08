import Foundation

public enum ContentStoreError: Error, Sendable, Equatable {
    case missingIndex
    case unsupportedSchema(Int)
    case contentVersionMismatch(expected: String, actual: String)
    case missingDocument(String)
    case invalidReference(String)
    case invalidAssetPath(String)
    case invalidJSON(String)
    case missingAsset(String)
    case checksumMismatch(asset: String, expected: String, actual: String)
}

public protocol ContentStore: Sendable {
    func index() async throws -> ContentIndex
    func course(id: CourseID) async throws -> CourseManifest
    func lesson(id: LessonID) async throws -> LessonDocument
    func assetURL(for reference: AssetReference) async throws -> URL
}

public protocol StoryContentStore: ContentStore {
    func stories() async throws -> [StoryDocument]
    func story(id: StoryID) async throws -> StoryDocument
}

public extension ContentStore {
    func stories() async throws -> [StoryDocument] { [] }
    func story(id: StoryID) async throws -> StoryDocument {
        throw ContentStoreError.missingDocument("stories/\(id.rawValue).json")
    }
}

public actor JSONContentStore: StoryContentStore {
    public let rootURL: URL
    public let supportedSchemaVersion: Int
    private var cachedIndex: ContentIndex?

    public init(rootURL: URL, supportedSchemaVersion: Int = 1) {
        self.rootURL = rootURL.standardizedFileURL
        self.supportedSchemaVersion = supportedSchemaVersion
    }

    public func index() async throws -> ContentIndex {
        if let cachedIndex { return cachedIndex }
        let value: ContentIndex = try readJSON(relativePath: "manifest.json")
        guard value.schemaVersion == supportedSchemaVersion else {
            throw ContentStoreError.unsupportedSchema(value.schemaVersion)
        }
        guard value.courseIDs.contains(value.defaultCourseID), !value.courseIDs.isEmpty else {
            throw ContentStoreError.invalidReference("defaultCourseID")
        }
        cachedIndex = value
        return value
    }

    public func course(id: CourseID) async throws -> CourseManifest {
        let manifest = try await index()
        guard manifest.courseIDs.contains(id) else {
            throw ContentStoreError.missingDocument(id.rawValue)
        }
        let course: CourseManifest = try readJSON(relativePath: "courses/\(id.rawValue).json")
        try validate(schemaVersion: course.schemaVersion, contentVersion: course.contentVersion, expected: manifest.contentVersion)
        guard course.id == id else { throw ContentStoreError.invalidReference("course.id") }
        var seenModules = Set<ModuleID>()
        var seenLessons = Set<LessonID>()
        for module in course.modules {
            guard seenModules.insert(module.id).inserted else { throw ContentStoreError.invalidReference("module.\(module.id.rawValue)") }
            for lessonID in module.lessonIDs {
                guard seenLessons.insert(lessonID).inserted else { throw ContentStoreError.invalidReference("lesson.\(lessonID.rawValue)") }
            }
        }
        return course
    }

    public func lesson(id: LessonID) async throws -> LessonDocument {
        let manifest = try await index()
        let lesson: LessonDocument = try readJSON(relativePath: "lessons/\(id.rawValue).json")
        try validate(schemaVersion: lesson.schemaVersion, contentVersion: lesson.contentVersion, expected: manifest.contentVersion)
        guard lesson.id == id else { throw ContentStoreError.invalidReference("lesson.id") }

        var exerciseIDs = Set<ExerciseID>()
        var blockIDs = Set<BlockID>()
        for block in lesson.blocks {
            guard blockIDs.insert(block.id).inserted else { throw ContentStoreError.invalidReference("block.\(block.id.rawValue)") }
            if case .exercise(let exerciseBlock) = block {
                guard exerciseIDs.insert(exerciseBlock.spec.id).inserted else { throw ContentStoreError.invalidReference("exercise.\(exerciseBlock.spec.id.rawValue)") }
            }
        }
        let vocabularyIDs = Set(lesson.vocabulary.map(\.id))
        for card in lesson.cards where !vocabularyIDs.contains(card.vocabularyID) {
            throw ContentStoreError.invalidReference("card.\(card.id.rawValue).vocabularyID")
        }
        return lesson
    }

    public func stories() async throws -> [StoryDocument] {
        let directory = rootURL.appendingPathComponent("stories", isDirectory: true)
        guard FileManager.default.fileExists(atPath: directory.path) else {
            // Reading blocks are complete, graded stories in the first content
            // tranche. Deriving this catalogue keeps Explorer useful even
            // when a later content pack has not introduced standalone files.
            let contentIndex = try await index()
            let courseManifest = try await course(id: contentIndex.defaultCourseID)
            var derived: [StoryDocument] = []
            for module in courseManifest.modules.sorted(by: { $0.order < $1.order }) {
                let moduleLevel = module.level?.trimmingCharacters(in: .whitespacesAndNewlines)
                let moduleLabel = contentLevelLabel(moduleLevel)
                    ?? contentLevelLabel(module.displayName?.resolve(preferred: ["fr", "en"]))
                for lessonID in module.lessonIDs {
                    let document = try await lesson(id: lessonID)
                    for block in document.blocks {
                        if case .reading(let reading) = block {
                            let level = contentLevelLabel(reading.level)
                                ?? contentLevelLabel(document.level)
                                ?? moduleLabel
                                ?? (module.id.rawValue == "unit-01" ? "HSK classique 1" : "Parcours")
                            derived.append(StoryDocument(id: reading.storyID, title: reading.title, summary: reading.title, level: level, estimatedMinutes: max(1, document.estimatedMinutes / 2), audio: nil, paragraphs: reading.paragraphs))
                        }
                    }
                }
            }
            return derived
        }
        let urls = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension.lowercased() == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        return try urls.compactMap { url in
            do { return try JSONDecoder().decode(StoryDocument.self, from: Data(contentsOf: url)) }
            catch { throw ContentStoreError.invalidJSON("\(url.lastPathComponent): \(error.localizedDescription)") }
        }
    }

    public func story(id: StoryID) async throws -> StoryDocument {
        guard let story = try await stories().first(where: { $0.id == id }) else {
            throw ContentStoreError.missingDocument("stories/\(id.rawValue).json")
        }
        return story
    }

    public func assetURL(for reference: AssetReference) async throws -> URL {
        guard !reference.relativePath.isEmpty,
              !reference.relativePath.hasPrefix("/"),
              !reference.relativePath.hasPrefix("~"),
              !reference.relativePath.split(separator: "/").contains(where: { $0 == ".." }),
              !reference.relativePath.split(separator: "\\").contains(where: { $0 == ".." }) else {
            throw ContentStoreError.invalidAssetPath(reference.relativePath)
        }
        let candidate = rootURL.appendingPathComponent(reference.relativePath, isDirectory: false).standardizedFileURL
        let resolved = candidate.resolvingSymlinksInPath().standardizedFileURL
        guard isWithinRoot(resolved), FileManager.default.fileExists(atPath: resolved.path) else {
            throw ContentStoreError.missingAsset(reference.relativePath)
        }
        guard !reference.sha256.isEmpty else {
            throw ContentStoreError.invalidReference("asset.\(reference.id.rawValue).sha256")
        }
        let data: Data
        do { data = try Data(contentsOf: resolved) }
        catch { throw ContentStoreError.missingAsset(reference.relativePath) }
        let actual = SHA256.hex(data)
        guard actual.caseInsensitiveCompare(reference.sha256) == .orderedSame else {
            throw ContentStoreError.checksumMismatch(asset: reference.id.rawValue, expected: reference.sha256, actual: actual)
        }
        return resolved
    }

    private func validate(schemaVersion: Int, contentVersion: String, expected: String) throws {
        guard schemaVersion == supportedSchemaVersion else { throw ContentStoreError.unsupportedSchema(schemaVersion) }
        guard contentVersion == expected else { throw ContentStoreError.contentVersionMismatch(expected: expected, actual: contentVersion) }
    }

    private func isWithinRoot(_ url: URL) -> Bool {
        let rootPath = rootURL.resolvingSymlinksInPath().standardizedFileURL.path
        let path = url.path
        return path == rootPath || path.hasPrefix(rootPath.hasSuffix("/") ? rootPath : rootPath + "/")
    }

    private func readJSON<Value: Decodable>(relativePath: String) throws -> Value {
        let fileURL = rootURL.appendingPathComponent(relativePath, isDirectory: false).standardizedFileURL
        let resolvedURL = fileURL.resolvingSymlinksInPath().standardizedFileURL
        guard isWithinRoot(resolvedURL), FileManager.default.fileExists(atPath: resolvedURL.path) else {
            throw ContentStoreError.missingDocument(relativePath)
        }
        do {
            let data = try Data(contentsOf: resolvedURL)
            return try JSONDecoder().decode(Value.self, from: data)
        } catch let error as ContentStoreError {
            throw error
        } catch {
            throw ContentStoreError.invalidJSON("\(relativePath): \(error.localizedDescription)")
        }
    }
}

private func contentLevelLabel(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    let normalized = trimmed.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    let looksLikeCurriculum = normalized.contains("hsk")
        || normalized.contains("cefr")
        || normalized.contains("cecr")
        || normalized.range(of: #"\b[a-c][1-2]\b"#, options: .regularExpression) != nil
    return looksLikeCurriculum ? trimmed : nil
}

private enum SHA256 {
    private static let constants: [UInt32] = [
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
        0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
        0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
        0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
        0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
        0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
        0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
        0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
        0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
    ]

    static func hex(_ data: Data) -> String {
        var bytes = Array(data)
        let bitLength = UInt64(bytes.count) * 8
        bytes.append(0x80)
        while (bytes.count + 8) % 64 != 0 { bytes.append(0) }
        bytes.append(contentsOf: [
            UInt8((bitLength >> 56) & 0xff), UInt8((bitLength >> 48) & 0xff),
            UInt8((bitLength >> 40) & 0xff), UInt8((bitLength >> 32) & 0xff),
            UInt8((bitLength >> 24) & 0xff), UInt8((bitLength >> 16) & 0xff),
            UInt8((bitLength >> 8) & 0xff), UInt8(bitLength & 0xff)
        ])

        var h: [UInt32] = [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19]
        for offset in stride(from: 0, to: bytes.count, by: 64) {
            var words = [UInt32](repeating: 0, count: 64)
            for i in 0..<16 {
                let index = offset + i * 4
                words[i] = UInt32(bytes[index]) << 24 | UInt32(bytes[index + 1]) << 16 | UInt32(bytes[index + 2]) << 8 | UInt32(bytes[index + 3])
            }
            for i in 16..<64 {
                let s0 = words[i - 15].rotateRight(7) ^ words[i - 15].rotateRight(18) ^ (words[i - 15] >> 3)
                let s1 = words[i - 2].rotateRight(17) ^ words[i - 2].rotateRight(19) ^ (words[i - 2] >> 10)
                words[i] = words[i - 16] &+ s0 &+ words[i - 7] &+ s1
            }
            var a = h[0], b = h[1], c = h[2], d = h[3], e = h[4], f = h[5], g = h[6], hh = h[7]
            for i in 0..<64 {
                let s1 = e.rotateRight(6) ^ e.rotateRight(11) ^ e.rotateRight(25)
                let choice = (e & f) ^ ((~e) & g)
                let temp1 = hh &+ s1 &+ choice &+ constants[i] &+ words[i]
                let s0 = a.rotateRight(2) ^ a.rotateRight(13) ^ a.rotateRight(22)
                let majority = (a & b) ^ (a & c) ^ (b & c)
                let temp2 = s0 &+ majority
                hh = g; g = f; f = e; e = d &+ temp1; d = c; c = b; b = a; a = temp1 &+ temp2
            }
            h[0] &+= a; h[1] &+= b; h[2] &+= c; h[3] &+= d; h[4] &+= e; h[5] &+= f; h[6] &+= g; h[7] &+= hh
        }
        return h.map { String(format: "%08x", $0) }.joined()
    }
}

private extension UInt32 {
    func rotateRight(_ amount: UInt32) -> UInt32 { (self >> amount) | (self << (32 - amount)) }
}
