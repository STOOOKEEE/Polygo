import Foundation
import PolygoCore
import PolygoSRS

/// Errors raised while reading or updating the local event store.
public enum ProgressStoreError: Error, Sendable, Equatable, LocalizedError {
    case corruptedJournal(line: Int)
    case unsupportedSnapshot(Int)
    case duplicateEvent(EventID)
    case ioFailure(String)

    public var errorDescription: String? {
        switch self {
        case .corruptedJournal(let line):
            return "Le journal de progression est corrompu à la ligne \(line)."
        case .unsupportedSnapshot(let version):
            return "La version du snapshot de progression (\(version)) n’est pas prise en charge."
        case .duplicateEvent(let id):
            return "L’identifiant d’événement \(id.rawValue) est déjà utilisé avec un contenu différent."
        case .ioFailure(let message):
            return "La progression locale n’a pas pu être enregistrée : \(message)"
        }
    }
}

/// The storage contract deliberately exposes the immutable events as the
/// source of truth and leaves the snapshot as a rebuildable cache.
public protocol ProgressStore: Sendable {
    func load(profileID: ProfileID) async throws -> ProgressSnapshot
    func append(_ event: ProgressEvent) async throws -> ProgressSnapshot
    func pendingEvents(profileID: ProfileID, limit: Int) async throws -> [ProgressEvent]
    func markSynced(eventIDs: [EventID], profileID: ProfileID) async throws
}

/// A local-first JSONL store.
///
/// Each profile gets its own directory under `rootURL/profiles`. The event
/// journal is rewritten atomically on every append. This costs more I/O than a
/// raw FileHandle append, but it means a process crash leaves either the old
/// complete journal or the new complete journal, never a newly half-written
/// JSON object. A final partial line produced by an older implementation is
/// copied to a recovery file before it is removed from the active journal.
public actor JSONFileProgressStore: ProgressStore {
    public let rootURL: URL
    public let reducer: any ProgressReducer

    private static let currentEventSchemaVersion = 1
    private static let outboxSchemaVersion = 1

    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        rootURL: URL,
        reducer: any ProgressReducer,
        fileManager: FileManager = .default
    ) {
        self.rootURL = rootURL.standardizedFileURL
        self.reducer = reducer
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder
        self.decoder = JSONDecoder()
    }

    public func load(profileID: ProfileID) async throws -> ProgressSnapshot {
        // Validate the cache when it exists. It is not used as authority, but
        // a future snapshot must not be silently downgraded by a new client.
        _ = try readSnapshot(profileID: profileID)
        let result = try rebuild(profileID: profileID)
        try writeSnapshot(result.snapshot, profileID: profileID)
        return result.snapshot
    }

    public func append(_ event: ProgressEvent) async throws -> ProgressSnapshot {
        let profileID = event.profileID
        _ = try readSnapshot(profileID: profileID)
        let current = try rebuild(profileID: profileID)

        // A non-empty snapshot with no journal is an incomplete installation,
        // not a safe starting point for a new append. Keep the cached data
        // readable, but refuse to overwrite it with a journal that cannot
        // represent its history. An empty first-launch snapshot is allowed.
        if !current.journalExists && !current.snapshot.isEmptyState {
            throw ProgressStoreError.ioFailure("journal absent alors qu’un snapshot contient déjà une progression")
        }

        if let existing = current.events.first(where: { $0.eventID == event.eventID }) {
            guard existing == event else {
                throw ProgressStoreError.duplicateEvent(event.eventID)
            }
            // Retrying after a snapshot I/O failure must be safe. The event is
            // already durable in the journal, so only repair the cache.
            try writeSnapshot(current.snapshot, profileID: profileID)
            return current.snapshot
        }

        guard event.schemaVersion == Self.currentEventSchemaVersion else {
            throw ProgressStoreError.ioFailure("Version d’événement non prise en charge : \(event.schemaVersion)")
        }

        let events = Self.sortedEvents(current.events + [event])
        let next = try reduce(events: events, profileID: profileID)

        do {
            try appendToJournal(event, existingEvents: current.events, profileID: profileID)
            try writeSnapshot(next, profileID: profileID)
        } catch let error as ProgressStoreError {
            throw error
        } catch {
            throw ProgressStoreError.ioFailure(error.localizedDescription)
        }
        return next
    }

    public func pendingEvents(profileID: ProfileID, limit: Int) async throws -> [ProgressEvent] {
        guard limit > 0 else { return [] }
        let journal = try readJournal(profileID: profileID)
        let acknowledged = try readAcknowledged(profileID: profileID)
        return Self.sortedEvents(journal.events)
            .filter { !acknowledged.contains($0.eventID) }
            .prefix(limit)
            .map { $0 }
    }

    public func markSynced(eventIDs: [EventID], profileID: ProfileID) async throws {
        guard !eventIDs.isEmpty else { return }
        let journal = try readJournal(profileID: profileID)
        let known = Set(journal.events.map(\.eventID))
        let idsToMark = Set(eventIDs).intersection(known)
        guard !idsToMark.isEmpty else { return }

        var acknowledged = try readAcknowledged(profileID: profileID)
        acknowledged.formUnion(idsToMark)
        try writeAcknowledged(acknowledged, profileID: profileID)
    }

    /// Returns all unique events in deterministic replay order. This is useful
    /// to diagnostics and to a future CloudKit adapter; the protocol itself
    /// intentionally stays as small as the app needs.
    public func events(profileID: ProfileID) async throws -> [ProgressEvent] {
        Self.sortedEvents(try readJournal(profileID: profileID).events)
    }

    /// Derives the SRS deck and its immutable history from the same event log.
    /// No second mutable database is needed for cards or reviews.
    public func reviewDeck(profileID: ProfileID) async throws -> ReviewDeck {
        let events = try Self.sortedEvents(readJournal(profileID: profileID).events)
        let scheduler = SM2Scheduler()
        var states: [CardID: ReviewState] = [:]
        var history: [CardID: [ReviewHistoryEntry]] = [:]
        var suspended: Set<CardID> = []

        for event in events {
            switch event.payload {
            case .flashcardAdded(let cardID, let date):
                if states[cardID] == nil {
                    states[cardID] = ReviewState(cardID: cardID, dueAt: date)
                }
            case .flashcardReviewed(let cardID, let rating, let date):
                let transition = scheduler.review(for: cardID, from: states[cardID], rating: rating, at: date)
                states[cardID] = transition.state
                history[cardID, default: []].append(transition.historyEntry)
            case .flashcardSuspended(let cardID, let isSuspended, let date):
                if isSuspended {
                    let current = states[cardID] ?? ReviewState(cardID: cardID, dueAt: date)
                    states[cardID] = scheduler.suspend(current, at: date)
                    suspended.insert(cardID)
                } else if let current = states[cardID] {
                    states[cardID] = scheduler.resume(current, at: date)
                    suspended.remove(cardID)
                }
            default:
                break
            }
        }
        return ReviewDeck(states: states, history: history, suspendedCardIDs: suspended)
    }

    /// Spelling retained for callers that model the deck as a loaded resource.
    public func loadReviewDeck(profileID: ProfileID) async throws -> ReviewDeck {
        try await reviewDeck(profileID: profileID)
    }

    // MARK: - Journal and snapshot

    private struct JournalRead {
        let events: [ProgressEvent]
        let exists: Bool
    }

    private struct OutboxFile: Codable {
        let schemaVersion: Int
        let acknowledgedEventIDs: Set<EventID>
    }

    private struct RebuildResult {
        let snapshot: ProgressSnapshot
        let events: [ProgressEvent]
        let journalExists: Bool
    }

    private func rebuild(profileID: ProfileID) throws -> RebuildResult {
        let journal = try readJournal(profileID: profileID)
        if !journal.exists, let cached = try readSnapshot(profileID: profileID) {
            return RebuildResult(snapshot: cached, events: [], journalExists: false)
        }
        if journal.events.isEmpty, let cached = try readSnapshot(profileID: profileID), !cached.isEmptyState {
            throw ProgressStoreError.ioFailure("journal vide alors qu’un snapshot contient déjà une progression")
        }
        let events = Self.sortedEvents(journal.events)
        let snapshot = try reduce(events: events, profileID: profileID)
        return RebuildResult(snapshot: snapshot, events: events, journalExists: journal.exists)
    }

    private func reduce(events: [ProgressEvent], profileID: ProfileID) throws -> ProgressSnapshot {
        var snapshot = ProgressSnapshot.empty()
        var seen: [EventID: ProgressEvent] = [:]
        for event in Self.sortedEvents(events) {
            guard event.profileID == profileID else {
                throw DomainError.eventProfileMismatch
            }
            guard event.schemaVersion == Self.currentEventSchemaVersion else {
                throw ProgressStoreError.ioFailure("Version d’événement non prise en charge : \(event.schemaVersion)")
            }
            if let previous = seen[event.eventID] {
                guard previous == event else {
                    throw ProgressStoreError.duplicateEvent(event.eventID)
                }
                continue
            }
            seen[event.eventID] = event
            snapshot = try reducer.reduce(snapshot, event: event)
        }
        return snapshot
    }

    private func readJournal(profileID: ProfileID) throws -> JournalRead {
        let url = journalURL(profileID: profileID)
        guard fileManager.fileExists(atPath: url.path) else {
            return JournalRead(events: [], exists: false)
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ProgressStoreError.ioFailure("lecture du journal : \(error.localizedDescription)")
        }

        let bytes = [UInt8](data)
        var events: [ProgressEvent] = []
        var byID: [EventID: ProgressEvent] = [:]
        var start = 0
        var lineNumber = 1

        while start <= bytes.count {
            var end = start
            while end < bytes.count && bytes[end] != 0x0A { end += 1 }
            let hasNewline = end < bytes.count
            let line = Data(bytes[start..<end])

            if !line.isEmpty {
                let event: ProgressEvent
                do {
                    event = try decoder.decode(ProgressEvent.self, from: line)
                } catch {
                    // A line terminated by a newline is a committed record and
                    // must fail loudly. Only an unterminated final line can be
                    // an interrupted write and is recoverable.
                    if !hasNewline && end == bytes.count {
                        try quarantinePartialLine(Data(bytes[start..<end]), journalURL: url)
                        try writeAtomically(Data(bytes[0..<start]), to: url)
                        break
                    }
                    throw ProgressStoreError.corruptedJournal(line: lineNumber)
                }
                guard event.schemaVersion == Self.currentEventSchemaVersion else {
                    throw ProgressStoreError.ioFailure("Version d’événement non prise en charge : \(event.schemaVersion)")
                }
                guard event.profileID == profileID else {
                    throw DomainError.eventProfileMismatch
                }
                if let previous = byID[event.eventID] {
                    guard previous == event else {
                        throw ProgressStoreError.duplicateEvent(event.eventID)
                    }
                } else {
                    byID[event.eventID] = event
                    events.append(event)
                }
            }

            if !hasNewline { break }
            start = end + 1
            lineNumber += 1
        }
        return JournalRead(events: events, exists: true)
    }

    private func appendToJournal(
        _ event: ProgressEvent,
        existingEvents: [ProgressEvent],
        profileID: ProfileID
    ) throws {
        let url = journalURL(profileID: profileID)
        let encoded: Data
        do {
            encoded = try encoder.encode(event)
        } catch {
            throw ProgressStoreError.ioFailure("encodage de l’événement : \(error.localizedDescription)")
        }

        var data = Data()
        if fileManager.fileExists(atPath: url.path) {
            do { data = try Data(contentsOf: url) }
            catch { throw ProgressStoreError.ioFailure("lecture du journal avant ajout : \(error.localizedDescription)") }
        } else if !existingEvents.isEmpty {
            throw ProgressStoreError.ioFailure("journal absent malgré des événements existants")
        }
        if !data.isEmpty && data.last != 0x0A { data.append(0x0A) }
        data.append(encoded)
        data.append(0x0A)
        try writeAtomically(data, to: url)
    }

    private func readSnapshot(profileID: ProfileID) throws -> ProgressSnapshot? {
        let url = snapshotURL(profileID: profileID)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let data: Data
        do { data = try Data(contentsOf: url) }
        catch { throw ProgressStoreError.ioFailure("lecture du snapshot : \(error.localizedDescription)") }
        do {
            let snapshot = try decoder.decode(ProgressSnapshot.self, from: data)
            guard snapshot.schemaVersion == ProgressSnapshot.currentSchemaVersion else {
                throw ProgressStoreError.unsupportedSnapshot(snapshot.schemaVersion)
            }
            if let profile = snapshot.profile, profile.id != profileID {
                throw DomainError.eventProfileMismatch
            }
            return snapshot
        } catch let error as ProgressStoreError {
            throw error
        } catch let error as DomainError {
            if case .eventProfileMismatch = error {
                throw error
            }
            try quarantine(data, originalURL: url, suffix: "corrupt", removeOriginal: true)
            return nil
        } catch {
            // A snapshot is only a cache. Preserve the bytes for diagnosis and
            // rebuild from the journal instead of hiding a recoverable failure.
            try quarantine(data, originalURL: url, suffix: "corrupt", removeOriginal: true)
            return nil
        }
    }

    private func writeSnapshot(_ snapshot: ProgressSnapshot, profileID: ProfileID) throws {
        do {
            let data = try encoder.encode(snapshot)
            try writeAtomically(data, to: snapshotURL(profileID: profileID))
        } catch let error as ProgressStoreError {
            throw error
        } catch {
            throw ProgressStoreError.ioFailure("écriture du snapshot : \(error.localizedDescription)")
        }
    }

    // MARK: - Outbox acknowledgement file

    private func readAcknowledged(profileID: ProfileID) throws -> Set<EventID> {
        let url = outboxURL(profileID: profileID)
        guard fileManager.fileExists(atPath: url.path) else { return [] }
        let data: Data
        do { data = try Data(contentsOf: url) }
        catch { throw ProgressStoreError.ioFailure("lecture de l’outbox : \(error.localizedDescription)") }
        do {
            let file = try decoder.decode(OutboxFile.self, from: data)
            guard file.schemaVersion == Self.outboxSchemaVersion else {
                throw ProgressStoreError.ioFailure("Version d’outbox non prise en charge : \(file.schemaVersion)")
            }
            return file.acknowledgedEventIDs
        } catch let error as ProgressStoreError {
            throw error
        } catch {
            // Losing an acknowledgement only causes a safe resend. Keep the
            // damaged metadata available and resume with an empty ack set.
            try quarantine(data, originalURL: url, suffix: "corrupt", removeOriginal: true)
            return []
        }
    }

    private func writeAcknowledged(_ ids: Set<EventID>, profileID: ProfileID) throws {
        do {
            let file = OutboxFile(schemaVersion: Self.outboxSchemaVersion, acknowledgedEventIDs: ids)
            try writeAtomically(encoder.encode(file), to: outboxURL(profileID: profileID))
        } catch let error as ProgressStoreError {
            throw error
        } catch {
            throw ProgressStoreError.ioFailure("écriture de l’outbox : \(error.localizedDescription)")
        }
    }

    // MARK: - Filesystem helpers

    private func profileURL(_ profileID: ProfileID) -> URL {
        rootURL
            .appendingPathComponent("profiles", isDirectory: true)
            .appendingPathComponent(profileID.rawValue, isDirectory: true)
    }

    private func journalURL(profileID: ProfileID) -> URL {
        profileURL(profileID).appendingPathComponent("events.jsonl", isDirectory: false)
    }

    private func snapshotURL(profileID: ProfileID) -> URL {
        profileURL(profileID).appendingPathComponent("snapshot.json", isDirectory: false)
    }

    private func outboxURL(profileID: ProfileID) -> URL {
        profileURL(profileID).appendingPathComponent("outbox.json", isDirectory: false)
    }

    private func writeAtomically(_ data: Data, to url: URL) throws {
        do {
            try ensureProfileDirectoryFromFileURL(url)
            try data.write(to: url, options: [.atomic])
        } catch let error as ProgressStoreError {
            throw error
        } catch {
            throw ProgressStoreError.ioFailure("écriture de \(url.lastPathComponent) : \(error.localizedDescription)")
        }
    }

    private func ensureProfileDirectoryFromFileURL(_ url: URL) throws {
        do {
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        } catch {
            throw ProgressStoreError.ioFailure("création du dossier local : \(error.localizedDescription)")
        }
    }

    private func quarantinePartialLine(_ data: Data, journalURL: URL) throws {
        guard !data.isEmpty else { return }
        try quarantine(data, originalURL: journalURL, suffix: "partial")
    }

    private func quarantine(
        _ data: Data,
        originalURL: URL,
        suffix: String,
        removeOriginal: Bool = false
    ) throws {
        let recoveryURL = originalURL.appendingPathExtension("\(suffix).\(UUID().uuidString)")
        do {
            try ensureProfileDirectoryFromFileURL(recoveryURL)
            try data.write(to: recoveryURL, options: [.atomic])
            if removeOriginal {
                try fileManager.removeItem(at: originalURL)
            }
        } catch let error as ProgressStoreError {
            throw error
        } catch {
            throw ProgressStoreError.ioFailure("sauvegarde de récupération : \(error.localizedDescription)")
        }
    }

    private static func sortedEvents(_ events: [ProgressEvent]) -> [ProgressEvent] {
        events.sorted {
            if $0.lamport != $1.lamport { return $0.lamport < $1.lamport }
            if $0.deviceID.rawValue != $1.deviceID.rawValue { return $0.deviceID.rawValue < $1.deviceID.rawValue }
            return $0.eventID.rawValue < $1.eventID.rawValue
        }
    }
}

public typealias LocalProgressStore = JSONFileProgressStore
public typealias FileProgressStore = JSONFileProgressStore

private extension ProgressSnapshot {
    var isEmptyState: Bool {
        profile == nil
            && lessonProgress.isEmpty
            && reviewStates.isEmpty
            && lastEventLamport == 0
            && processedEventIDs.isEmpty
            && activeRoute == nil
    }
}
