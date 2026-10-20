import Foundation

public enum OperationalCommandKind: String, Codable, Sendable {
    case parent
    case daily
}

public enum OperationalCommandVersionState: String, Codable, Sendable {
    case draft
    case published
    case superseded
    case withdrawn
}

public enum OperationalCommandTargetKind: String, Codable, Sendable {
    case plan
    case activity
    case objective
}

public struct OperationalCommandTarget: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID { targetID }
    public let kind: OperationalCommandTargetKind
    public let targetID: UUID

    public init(kind: OperationalCommandTargetKind, targetID: UUID) {
        self.kind = kind
        self.targetID = targetID
    }
}

public struct OperationalCommandItem: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID { occurrenceID }
    public let occurrenceID: UUID
    public let parentVersionID: UUID?

    public init(occurrenceID: UUID, parentVersionID: UUID? = nil) {
        self.occurrenceID = occurrenceID
        self.parentVersionID = parentVersionID
    }
}

public struct OperationalCommandDraftContent: Codable, Equatable, Sendable {
    public let title: String
    public let details: String?
    public let classification: String?
    public let priority: Int?
    public let effectiveDate: String?
    public let targets: [OperationalCommandTarget]
    public let items: [OperationalCommandItem]

    public init(
        title: String,
        details: String? = nil,
        classification: String? = nil,
        priority: Int? = nil,
        effectiveDate: String? = nil,
        targets: [OperationalCommandTarget] = [],
        items: [OperationalCommandItem] = []
    ) throws {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { throw PlanningValidationError.emptyTitle }
        guard Set(targets.map(\.id)).count == targets.count,
              Set(items.map(\.occurrenceID)).count == items.count else {
            throw OperationalCommandValidationError.duplicateReference
        }
        self.title = title
        self.details = details?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.classification = classification?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.priority = priority
        if let effectiveDate {
            try Plan.validateDate(effectiveDate)
        }
        self.effectiveDate = effectiveDate
        self.targets = targets
        self.items = items
    }
}

public struct OperationalCommandSnapshotTarget: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID { targetID }
    public let kind: OperationalCommandTargetKind
    public let targetID: UUID
    public let title: String
    public let details: String?
    public let startDate: String?
    public let endDate: String?

    public init(
        kind: OperationalCommandTargetKind,
        targetID: UUID,
        title: String,
        details: String?,
        startDate: String? = nil,
        endDate: String? = nil
    ) {
        self.kind = kind
        self.targetID = targetID
        self.title = title
        self.details = details
        self.startDate = startDate
        self.endDate = endDate
    }
}

public struct OperationalCommandSnapshotParent: Codable, Equatable, Sendable {
    public let versionID: UUID
    public let number: String
    public let versionNumber: Int
    public let title: String
    public let details: String?
    public let date: String?
    public let classification: String?
    public let priority: Int?

    public init(
        versionID: UUID,
        number: String,
        versionNumber: Int,
        title: String,
        details: String?,
        date: String?,
        classification: String?,
        priority: Int?
    ) {
        self.versionID = versionID
        self.number = number
        self.versionNumber = versionNumber
        self.title = title
        self.details = details
        self.date = date
        self.classification = classification
        self.priority = priority
    }
}

public struct OperationalCommandSnapshotItem: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID { occurrenceID }
    public let occurrenceID: UUID
    public let activityID: UUID
    public let title: String
    public let details: String?
    public let date: String
    public let startTime: String?
    public let endTime: String?
    public let priority: Int?
    public let order: Int
    public let parent: OperationalCommandSnapshotParent?

    public init(
        occurrenceID: UUID,
        activityID: UUID,
        title: String,
        details: String?,
        date: String,
        startTime: String?,
        endTime: String?,
        priority: Int?,
        order: Int,
        parent: OperationalCommandSnapshotParent?
    ) {
        self.occurrenceID = occurrenceID
        self.activityID = activityID
        self.title = title
        self.details = details
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.priority = priority
        self.order = order
        self.parent = parent
    }
}

public struct OperationalCommandSnapshot: Codable, Equatable, Sendable {
    public let kind: OperationalCommandKind
    public let number: String
    public let versionNumber: Int
    public let title: String
    public let details: String?
    public let date: String?
    public let classification: String?
    public let priority: Int?
    public let targets: [OperationalCommandSnapshotTarget]
    public let items: [OperationalCommandSnapshotItem]

    public init(
        kind: OperationalCommandKind,
        number: String,
        versionNumber: Int,
        title: String,
        details: String?,
        date: String?,
        classification: String?,
        priority: Int?,
        targets: [OperationalCommandSnapshotTarget],
        items: [OperationalCommandSnapshotItem]
    ) {
        self.kind = kind
        self.number = number
        self.versionNumber = versionNumber
        self.title = title
        self.details = details
        self.date = date
        self.classification = classification
        self.priority = priority
        self.targets = targets
        self.items = items
    }
}

public struct OperationalCommand: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let kind: OperationalCommandKind
    public let number: String
    public let date: String?
    public let createdAt: Date
    public let latestVersionNumber: Int
    public let currentPublishedVersionID: UUID?

    public init(
        id: UUID,
        kind: OperationalCommandKind,
        number: String,
        date: String?,
        createdAt: Date,
        latestVersionNumber: Int,
        currentPublishedVersionID: UUID?
    ) {
        self.id = id
        self.kind = kind
        self.number = number
        self.date = date
        self.createdAt = createdAt
        self.latestVersionNumber = latestVersionNumber
        self.currentPublishedVersionID = currentPublishedVersionID
    }
}

public struct OperationalCommandVersion: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let commandID: UUID
    public let number: String
    public let versionNumber: Int
    public let state: OperationalCommandVersionState
    public let createdAt: Date
    public let publishedAt: Date?
    public let content: OperationalCommandDraftContent
    public let snapshot: OperationalCommandSnapshot?
    public let replacedByVersionID: UUID?

    public init(
        id: UUID,
        commandID: UUID,
        number: String,
        versionNumber: Int,
        state: OperationalCommandVersionState,
        createdAt: Date,
        publishedAt: Date?,
        content: OperationalCommandDraftContent,
        snapshot: OperationalCommandSnapshot?,
        replacedByVersionID: UUID?
    ) {
        self.id = id
        self.commandID = commandID
        self.number = number
        self.versionNumber = versionNumber
        self.state = state
        self.createdAt = createdAt
        self.publishedAt = publishedAt
        self.content = content
        self.snapshot = snapshot
        self.replacedByVersionID = replacedByVersionID
    }
}

public enum OperationalCommandValidationError: Error, Equatable, LocalizedError {
    case duplicateReference
    case wrongTargetKind
    case occurrenceDateMismatch
    case missingReference
    case parentVersionNotPublished
    case invalidPriority
    case versionIsNotDraft
    case draftAlreadyExists
    case versionIsNotCurrentPublished
    case corruptedStoredContent

    public var errorDescription: String? {
        switch self {
        case .duplicateReference: "A command cannot contain the same target or occurrence twice."
        case .wrongTargetKind: "The selected command target has the wrong kind."
        case .occurrenceDateMismatch: "A daily command can only include occurrences scheduled on its date."
        case .missingReference: "A selected planning item no longer exists. Reload and try again."
        case .parentVersionNotPublished: "A daily item can only reference a published parent command version."
        case .invalidPriority: "Priority must be a whole number when provided."
        case .versionIsNotDraft: "Only a draft command version can be edited or published."
        case .draftAlreadyExists: "Finish or remove the existing draft before creating another revision."
        case .versionIsNotCurrentPublished: "Only the current published version can be revised or withdrawn."
        case .corruptedStoredContent: "The saved command content could not be read."
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
