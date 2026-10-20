import Foundation
import GRDB

public struct EvaluationRepository {
    private let databaseQueue: DatabaseQueue

    public init(databaseQueue: DatabaseQueue) {
        self.databaseQueue = databaseQueue
    }

    @discardableResult
    public func createRubric(title: String, classification: String, criteria: [String]) throws -> EvaluationRubricVersion {
        let rubricID = UUID()
        let rubric = try makeRubric(
            rubricID: rubricID,
            title: title,
            versionNumber: 1,
            classification: classification,
            criteria: criteria
        )
        try databaseQueue.write { db in
            try db.execute(
                sql: "INSERT INTO evaluation_rubrics (id, title, created_at) VALUES (?, ?, ?)",
                arguments: [rubricID.uuidString.lowercased(), rubric.title, rubric.createdAt.timeIntervalSince1970]
            )
            try insert(rubric, into: db)
        }
        return rubric
    }

    @discardableResult
    public func reviseRubric(
        rubricID: UUID,
        title: String,
        classification: String,
        criteria: [String]
    ) throws -> EvaluationRubricVersion {
        try databaseQueue.write { db in
            guard let current = try fetchRubrics(db).first(where: { $0.rubricID == rubricID }) else {
                throw EvaluationRepositoryError.rubricNotFound
            }
            let revision = try makeRubric(
                rubricID: rubricID,
                title: title,
                versionNumber: current.versionNumber + 1,
                classification: classification,
                criteria: criteria
            )
            try db.execute(sql: "UPDATE evaluation_rubrics SET title = ? WHERE id = ?", arguments: [revision.title, rubricID.uuidString.lowercased()])
            try insert(revision, into: db)
            return revision
        }
    }

    public func rubrics() throws -> [EvaluationRubricVersion] {
        try databaseQueue.read(fetchRubrics)
    }

    @discardableResult
    public func saveEvaluation(
        executionRecordID: UUID,
        rubric: EvaluationRubricVersion,
        responses: [UUID: String]
    ) throws -> EvaluationVersion {
        let allowedCriterionIDs = Set(rubric.criteria.map(\.id))
        guard Set(responses.keys).isSubset(of: allowedCriterionIDs) else {
            throw EvaluationRepositoryError.responseForUnknownCriterion
        }
        let normalizedResponses = responses.reduce(into: [UUID: String]()) { result, pair in
            let value = pair.value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty { result[pair.key] = value }
        }

        return try databaseQueue.write { db in
            let existing = try Row.fetchOne(
                db,
                sql: "SELECT id FROM evaluations WHERE execution_record_id = ?",
                arguments: [executionRecordID.uuidString.lowercased()]
            )
            let evaluationID: UUID
            let nextVersion: Int
            if let existing {
                evaluationID = try UUID(rowValue: existing["id"])
                nextVersion = (try Int.fetchOne(
                    db,
                    sql: "SELECT COALESCE(MAX(version_number), 0) + 1 FROM evaluation_versions WHERE evaluation_id = ?",
                    arguments: [evaluationID.uuidString.lowercased()]
                )) ?? 1
            } else {
                evaluationID = UUID()
                nextVersion = 1
                try db.execute(
                    sql: "INSERT INTO evaluations (id, execution_record_id, created_at) VALUES (?, ?, ?)",
                    arguments: [evaluationID.uuidString.lowercased(), executionRecordID.uuidString.lowercased(), Date.now.timeIntervalSince1970]
                )
            }

            let versionID = UUID()
            try db.execute(
                sql: """
                    INSERT INTO evaluation_versions
                        (id, evaluation_id, version_number, rubric_version_id, responses_json, created_at)
                    VALUES (?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    versionID.uuidString.lowercased(),
                    evaluationID.uuidString.lowercased(),
                    nextVersion,
                    rubric.id.uuidString.lowercased(),
                    try Self.encode(normalizedResponses),
                    Date.now.timeIntervalSince1970
                ]
            )
            return EvaluationVersion(
                id: versionID,
                evaluationID: evaluationID,
                executionRecordID: executionRecordID,
                versionNumber: nextVersion,
                rubric: rubric,
                responses: normalizedResponses
            )
        }
    }

    public func latestEvaluation(executionRecordID: UUID) throws -> EvaluationVersion? {
        try evaluationHistory(executionRecordID: executionRecordID).first
    }

    public func evaluationHistory(executionRecordID: UUID) throws -> [EvaluationVersion] {
        try databaseQueue.read { db in
            try Row.fetchAll(
                db,
                sql: """
                    SELECT e.id AS evaluation_id, e.execution_record_id, v.version_number,
                           v.id AS evaluation_version_id, v.rubric_version_id, v.responses_json,
                           v.created_at AS evaluation_created_at,
                           r.rubric_id, r.version_number AS rubric_version_number, r.classification,
                           r.criteria_json, r.created_at AS rubric_created_at, r.title
                    FROM evaluations e
                    JOIN evaluation_versions v ON v.evaluation_id = e.id
                    JOIN evaluation_rubric_versions r ON r.id = v.rubric_version_id
                    JOIN evaluation_rubrics parent ON parent.id = r.rubric_id
                    WHERE e.execution_record_id = ?
                    ORDER BY v.version_number DESC
                    """,
                arguments: [executionRecordID.uuidString.lowercased()]
            ).map(decodeEvaluation)
        }
    }

    private func fetchRubrics(_ db: Database) throws -> [EvaluationRubricVersion] {
        try Row.fetchAll(
            db,
            sql: """
                SELECT r.id, r.rubric_id, r.title, r.version_number,
                       r.classification, r.criteria_json, r.created_at
                FROM evaluation_rubric_versions r
                JOIN evaluation_rubrics parent ON parent.id = r.rubric_id
                ORDER BY parent.created_at DESC, r.version_number DESC
                """
        ).map { row in
            try EvaluationRubricVersion(
                id: UUID(rowValue: row["id"]),
                rubricID: UUID(rowValue: row["rubric_id"]),
                title: row["title"],
                versionNumber: row["version_number"],
                classification: row["classification"],
                criteria: try Self.decode([EvaluationCriterion].self, from: row["criteria_json"]),
                createdAt: Date(timeIntervalSince1970: row["created_at"])
            )
        }
    }

    private func insert(_ rubric: EvaluationRubricVersion, into db: Database) throws {
        try db.execute(
            sql: """
                INSERT INTO evaluation_rubric_versions
                    (id, rubric_id, version_number, title, classification, criteria_json, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
            arguments: [
                rubric.id.uuidString.lowercased(), rubric.rubricID.uuidString.lowercased(), rubric.versionNumber,
                rubric.title, rubric.classification, try Self.encode(rubric.criteria), rubric.createdAt.timeIntervalSince1970
            ]
        )
    }

    private func makeRubric(
        rubricID: UUID,
        title: String,
        versionNumber: Int,
        classification: String,
        criteria: [String]
    ) throws -> EvaluationRubricVersion {
        try EvaluationRubricVersion(
            rubricID: rubricID,
            title: title,
            versionNumber: versionNumber,
            classification: classification,
            criteria: criteria.map { try EvaluationCriterion(title: $0) }
        )
    }

    private func decodeEvaluation(_ row: Row) throws -> EvaluationVersion {
        let rubric = try EvaluationRubricVersion(
            id: UUID(rowValue: row["rubric_version_id"]),
            rubricID: UUID(rowValue: row["rubric_id"]),
            title: row["title"],
            versionNumber: row["rubric_version_number"],
            classification: row["classification"],
            criteria: try Self.decode([EvaluationCriterion].self, from: row["criteria_json"]),
            createdAt: Date(timeIntervalSince1970: row["rubric_created_at"])
        )
        return EvaluationVersion(
            id: try UUID(rowValue: row["evaluation_version_id"]),
            evaluationID: try UUID(rowValue: row["evaluation_id"]),
            executionRecordID: try UUID(rowValue: row["execution_record_id"]),
            versionNumber: row["version_number"],
            rubric: rubric,
            responses: try Self.decode([UUID: String].self, from: row["responses_json"]),
            createdAt: Date(timeIntervalSince1970: row["evaluation_created_at"])
        )
    }

    private static func encode<Value: Encodable>(_ value: Value) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }

    private static func decode<Value: Decodable>(_ type: Value.Type, from value: String) throws -> Value {
        try JSONDecoder().decode(type, from: Data(value.utf8))
    }
}

public enum EvaluationRepositoryError: Error, Equatable, LocalizedError {
    case rubricNotFound
    case responseForUnknownCriterion
    case invalidStoredIdentifier

    public var errorDescription: String? {
        switch self {
        case .rubricNotFound: "The evaluation rubric could not be found."
        case .responseForUnknownCriterion: "An evaluation response does not belong to the selected rubric."
        case .invalidStoredIdentifier: "An evaluation record contains an invalid identifier."
        }
    }
}

private extension UUID {
    init(rowValue: String) throws {
        guard let value = UUID(uuidString: rowValue) else {
            throw EvaluationRepositoryError.invalidStoredIdentifier
        }
        self = value
    }
}
