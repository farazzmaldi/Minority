import Foundation

public enum EvaluationValidationError: Error, Equatable, LocalizedError {
    case emptyTitle
    case emptyClassification
    case noCriteria
    case duplicateCriterion
    case emptyCriterion
    case invalidVersion
    case invalidTimestamp

    public var errorDescription: String? {
        switch self {
        case .emptyTitle: "A rubric title is required."
        case .emptyClassification: "A classification is required."
        case .noCriteria: "At least one rubric criterion is required."
        case .duplicateCriterion: "Rubric criteria must have unique identifiers."
        case .emptyCriterion: "A criterion title is required."
        case .invalidVersion: "A rubric version must be greater than zero."
        case .invalidTimestamp: "The rubric creation time is invalid."
        }
    }
}

public struct EvaluationCriterion: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let title: String

    public init(id: UUID = UUID(), title: String) throws {
        let value = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw EvaluationValidationError.emptyCriterion }
        self.id = id
        self.title = value
    }
}

public struct EvaluationRubricVersion: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let rubricID: UUID
    public let title: String
    public let versionNumber: Int
    public let classification: String
    public let criteria: [EvaluationCriterion]
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        rubricID: UUID = UUID(),
        title: String,
        versionNumber: Int = 1,
        classification: String,
        criteria: [EvaluationCriterion],
        createdAt: Date = .now
    ) throws {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedClassification = classification.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTitle.isEmpty else { throw EvaluationValidationError.emptyTitle }
        guard !normalizedClassification.isEmpty else { throw EvaluationValidationError.emptyClassification }
        guard !criteria.isEmpty else { throw EvaluationValidationError.noCriteria }
        guard Set(criteria.map(\.id)).count == criteria.count else { throw EvaluationValidationError.duplicateCriterion }
        guard versionNumber > 0 else { throw EvaluationValidationError.invalidVersion }
        guard createdAt.timeIntervalSince1970.isFinite else { throw EvaluationValidationError.invalidTimestamp }

        self.id = id
        self.rubricID = rubricID
        self.title = normalizedTitle
        self.versionNumber = versionNumber
        self.classification = normalizedClassification
        self.criteria = criteria
        self.createdAt = createdAt
    }
}

public struct EvaluationVersion: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let evaluationID: UUID
    public let executionRecordID: UUID
    public let versionNumber: Int
    public let rubric: EvaluationRubricVersion
    public let responses: [UUID: String]
    public let createdAt: Date

    public var isComplete: Bool {
        rubric.criteria.allSatisfy { criterion in
            guard let response = responses[criterion.id] else { return false }
            return !response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    public init(
        id: UUID = UUID(),
        evaluationID: UUID = UUID(),
        executionRecordID: UUID,
        versionNumber: Int = 1,
        rubric: EvaluationRubricVersion,
        responses: [UUID: String],
        createdAt: Date = .now
    ) {
        self.id = id
        self.evaluationID = evaluationID
        self.executionRecordID = executionRecordID
        self.versionNumber = versionNumber
        self.rubric = rubric
        self.responses = responses
        self.createdAt = createdAt
    }
}
