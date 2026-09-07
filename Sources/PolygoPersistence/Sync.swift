import Foundation
import PolygoCore

/// Opaque server position. CloudKit can encode a private change token here;
/// tests and other transports can use any stable bytes without coupling the
/// store to a CloudKit type.
public struct SyncCursor: Codable, Hashable, Sendable {
    public let opaqueValue: Data

    public init(opaqueValue: Data) {
        self.opaqueValue = opaqueValue
    }

    public init(_ opaqueValue: Data) {
        self.init(opaqueValue: opaqueValue)
    }
}

public struct SyncPushResult: Codable, Hashable, Sendable {
    public let accepted: [EventID]
    public let duplicates: [EventID]

    public init(accepted: [EventID] = [], duplicates: [EventID] = []) {
        self.accepted = accepted
        self.duplicates = duplicates
    }
}

public struct SyncPullResult: Codable, Hashable, Sendable {
    public let events: [ProgressEvent]
    public let cursor: SyncCursor?

    public init(events: [ProgressEvent] = [], cursor: SyncCursor? = nil) {
        self.events = events
        self.cursor = cursor
    }
}

/// Network/cloud adapters implement this protocol. There is intentionally no
/// default fake client in the production module: the app only shows a sync
/// action after a real adapter has been configured.
public protocol CloudSyncClient: Sendable {
    func push(_ events: [ProgressEvent]) async throws -> SyncPushResult
    func pull(after cursor: SyncCursor?) async throws -> SyncPullResult
}

public enum SyncError: Error, Sendable, Equatable, LocalizedError {
    case invalidBatchSize
    case noPushProgress
    case cursorDidNotAdvance

    public var errorDescription: String? {
        switch self {
        case .invalidBatchSize: return "La taille de lot de synchronisation doit être positive."
        case .noPushProgress: return "Le serveur n’a confirmé aucun événement ; la synchronisation est suspendue."
        case .cursorDidNotAdvance: return "Le serveur n’a pas fait progresser le curseur de synchronisation."
        }
    }
}

public struct SyncReport: Codable, Hashable, Sendable {
    public let pushedEventCount: Int
    public let pulledEventCount: Int
    public let cursor: SyncCursor?

    public init(pushedEventCount: Int, pulledEventCount: Int, cursor: SyncCursor?) {
        self.pushedEventCount = pushedEventCount
        self.pulledEventCount = pulledEventCount
        self.cursor = cursor
    }

    public var pushed: Int { pushedEventCount }
    public var pulled: Int { pulledEventCount }
}

public typealias SyncResult = SyncReport

/// Coordinates retry-safe push and pull operations around a local store.
///
/// A push is acknowledged only after the server response has arrived and been
/// durably recorded by `markSynced`. A pull cursor is committed only after all
/// events in that response have been appended locally. If either operation
/// fails, retrying the coordinator is safe: event IDs make both sides
/// idempotent and the old cursor is retained.
public actor SyncCoordinator {
    public let profileID: ProfileID
    public let batchSize: Int

    private let store: any ProgressStore
    private let client: any CloudSyncClient
    private var cursor: SyncCursor?

    public init(
        store: any ProgressStore,
        client: any CloudSyncClient,
        profileID: ProfileID,
        batchSize: Int = 50,
        cursor: SyncCursor? = nil
    ) {
        self.store = store
        self.client = client
        self.profileID = profileID
        self.batchSize = batchSize
        self.cursor = cursor
    }

    public init(
        profileID: ProfileID,
        store: any ProgressStore,
        client: any CloudSyncClient,
        batchSize: Int = 50,
        cursor: SyncCursor? = nil
    ) {
        self.init(store: store, client: client, profileID: profileID, batchSize: batchSize, cursor: cursor)
    }

    public var currentCursor: SyncCursor? { cursor }

    public func setCursor(_ cursor: SyncCursor?) {
        self.cursor = cursor
    }

    public func sync() async throws -> SyncReport {
        guard batchSize > 0 else { throw SyncError.invalidBatchSize }

        var pushedCount = 0
        while true {
            let pending = try await store.pendingEvents(profileID: profileID, limit: batchSize)
            guard !pending.isEmpty else { break }

            let result = try await client.push(pending)
            let pendingIDs = Set(pending.map(\.eventID))
            let confirmed = Set(result.accepted + result.duplicates).intersection(pendingIDs)
            guard !confirmed.isEmpty else { throw SyncError.noPushProgress }

            // If this write fails, the server response is deliberately not
            // remembered in memory; the same IDs remain pending and can be
            // resent safely.
            try await store.markSynced(eventIDs: Array(confirmed), profileID: profileID)
            pushedCount += confirmed.count
        }

        var pulledCount = 0
        while true {
            let oldCursor = cursor
            let result = try await client.pull(after: oldCursor)
            let ordered = result.events
                .filter { $0.profileID == profileID }
                .sorted(by: Self.eventOrder)

            // A server must not make a client silently discard another
            // profile's events. Mismatched data is rejected before any local
            // event from this response is appended.
            guard ordered.count == result.events.count else {
                throw DomainError.eventProfileMismatch
            }
            for event in ordered {
                _ = try await store.append(event)
            }
            pulledCount += ordered.count

            if result.cursor == oldCursor && !ordered.isEmpty {
                // Events are safely stored, but retaining the old cursor is
                // necessary so a later retry can ask for the same page. Do not
                // spin forever on a broken transport.
                throw SyncError.cursorDidNotAdvance
            }
            cursor = result.cursor
            if ordered.isEmpty { break }
        }

        return SyncReport(pushedEventCount: pushedCount, pulledEventCount: pulledCount, cursor: cursor)
    }

    public func synchronize() async throws -> SyncReport {
        try await sync()
    }

    public func syncNow() async throws -> SyncReport {
        try await sync()
    }

    private static func eventOrder(_ lhs: ProgressEvent, _ rhs: ProgressEvent) -> Bool {
        if lhs.lamport != rhs.lamport { return lhs.lamport < rhs.lamport }
        if lhs.deviceID.rawValue != rhs.deviceID.rawValue { return lhs.deviceID.rawValue < rhs.deviceID.rawValue }
        return lhs.eventID.rawValue < rhs.eventID.rawValue
    }
}
