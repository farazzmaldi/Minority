import CryptoKit
import Foundation
import GRDB

public struct SearchIndexRecord: Equatable, Sendable {
    public let id: String
    public let kind: String
    public let title: String
    public let body: String
    public let fingerprint: String

    public init(id: String, kind: String, title: String, body: String) {
        self.id = id
        self.kind = kind
        self.title = title
        self.body = body
        fingerprint = SHA256.hash(data: Data("\(kind)\u{0}\(title)\u{0}\(body)".utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

public struct LocalSearchResult: Identifiable, Equatable, Sendable {
    public let id: String
    public let kind: String
    public let title: String
    public let snippet: String
    public let relevance: Double
}

public struct SemanticSearchVector: Equatable, Sendable {
    public let record: SearchIndexRecord
    public let chunkIndex: Int
    public let vector: [Float]
}

public struct SearchRepository {
    private let databaseQueue: DatabaseQueue
    public init(databaseQueue: DatabaseQueue) { self.databaseQueue = databaseQueue }

    public func refreshIndex() throws {
        let records = try sourceRecords()
        try databaseQueue.write { db in
            let currentIDs = Set(try String.fetchAll(db, sql: "SELECT id FROM search_index"))
            let incomingIDs = Set(records.map(\.id))
            for staleID in currentIDs.subtracting(incomingIDs) {
                try db.execute(sql: "DELETE FROM search_fts WHERE record_id = ?", arguments: [staleID])
                try db.execute(sql: "DELETE FROM search_index WHERE id = ?", arguments: [staleID])
            }
            for record in records {
                let oldFingerprint = try String.fetchOne(db, sql: "SELECT fingerprint FROM search_index WHERE id = ?", arguments: [record.id])
                guard oldFingerprint != record.fingerprint else { continue }
                try db.execute(sql: "DELETE FROM search_fts WHERE record_id = ?", arguments: [record.id])
                try db.execute(sql: "DELETE FROM semantic_vectors WHERE record_id = ?", arguments: [record.id])
                try db.execute(sql: """
                    INSERT INTO search_index (id, kind, title, body, fingerprint, indexed_at)
                    VALUES (?, ?, ?, ?, ?, ?)
                    ON CONFLICT(id) DO UPDATE SET kind=excluded.kind, title=excluded.title,
                        body=excluded.body, fingerprint=excluded.fingerprint, indexed_at=excluded.indexed_at
                    """, arguments: [record.id, record.kind, record.title, record.body, record.fingerprint, Date.now.timeIntervalSince1970])
                try db.execute(sql: "INSERT INTO search_fts (record_id, title, body) VALUES (?, ?, ?)",
                               arguments: [record.id, record.title, record.body])
            }
        }
    }

    public func textSearch(_ query: String, limit: Int = 30) throws -> [LocalSearchResult] {
        let terms = query.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        guard !terms.isEmpty else { return [] }
        let match: String = terms.map { term in
            let escaped = term.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\"*"
        }.joined(separator: " OR ")
        return try databaseQueue.read { db in
            try Row.fetchAll(db, sql: """
                SELECT s.id, s.kind, s.title, s.body, bm25(search_fts, 0.0, 5.0, 1.0) AS rank
                FROM search_fts JOIN search_index s ON s.id = search_fts.record_id
                WHERE search_fts MATCH ? ORDER BY rank ASC, s.title COLLATE NOCASE, s.id LIMIT ?
                """, arguments: [match, limit]).map { row in
                    LocalSearchResult(id: row["id"], kind: row["kind"], title: row["title"],
                                      snippet: String((row["body"] as String).prefix(240)),
                                      relevance: row["rank"])
                }
        }
    }

    public func semanticIndexRecords() throws -> [SearchIndexRecord] {
        try databaseQueue.read { db in
            try Row.fetchAll(db, sql: "SELECT id, kind, title, body FROM search_index ORDER BY id").map(Self.decodeRecord)
        }
    }

    public func semanticVectors(modelIdentifier: String, revision: Int) throws -> [SemanticSearchVector] {
        try databaseQueue.read { db in
            try Row.fetchAll(db, sql: """
                SELECT s.id, s.kind, s.title, s.body, v.chunk_index, v.dimension, v.vector
                FROM semantic_vectors v JOIN search_index s ON s.id = v.record_id
                WHERE v.model_identifier = ? AND v.model_revision = ? ORDER BY s.id, v.chunk_index
                """, arguments: [modelIdentifier, revision]).map { row in
                    let data: Data = row["vector"]
                    let dimension: Int = row["dimension"]
                    let vector = data.withUnsafeBytes { Array($0.bindMemory(to: Float.self).prefix(dimension)) }
                    guard vector.count == dimension else { throw SearchRepositoryError.invalidStoredVector }
                    return SemanticSearchVector(record: try Self.decodeRecord(row),
                                                chunkIndex: row["chunk_index"], vector: vector)
                }
        }
    }

    public func replaceSemanticVectors(for record: SearchIndexRecord, modelIdentifier: String,
                                       revision: Int, vectors: [[Float]]) throws {
        try databaseQueue.write { db in
            guard try String.fetchOne(db, sql: "SELECT fingerprint FROM search_index WHERE id = ?",
                                      arguments: [record.id]) == record.fingerprint else {
                throw SearchRepositoryError.sourceChangedDuringIndexing
            }
            try db.execute(sql: "DELETE FROM semantic_vectors WHERE record_id = ? AND model_identifier = ? AND model_revision = ?",
                           arguments: [record.id, modelIdentifier, revision])
            for (index, vector) in vectors.enumerated() where !vector.isEmpty {
                let sanitized = vector.map { $0.isFinite ? $0 : 0 }
                let data = sanitized.withUnsafeBufferPointer { Data(buffer: $0) }
                try db.execute(sql: """
                    INSERT INTO semantic_vectors
                        (record_id, chunk_index, model_identifier, model_revision, dimension, vector)
                    VALUES (?, ?, ?, ?, ?, ?)
                    """, arguments: [record.id, index, modelIdentifier, revision, sanitized.count, data])
            }
        }
    }

    public func semanticSearch(queryVector: [Float], modelIdentifier: String, revision: Int,
                               limit: Int = 30) throws -> [LocalSearchResult] {
        let vectors = try semanticVectors(modelIdentifier: modelIdentifier, revision: revision)
        var best: [String: (SearchIndexRecord, Float)] = [:]
        for item in vectors where item.vector.count == queryVector.count {
            let score = zip(queryVector, item.vector).reduce(Float.zero) { $0 + $1.0 * $1.1 }
            if score.isFinite, score > (best[item.record.id]?.1 ?? -Float.infinity) {
                best[item.record.id] = (item.record, score)
            }
        }
        return best.values.sorted { $0.1 > $1.1 }.prefix(limit).map { record, score in
            LocalSearchResult(id: record.id, kind: record.kind, title: record.title,
                              snippet: String(record.body.prefix(240)), relevance: Double(score))
        }
    }

    private func sourceRecords() throws -> [SearchIndexRecord] {
        try databaseQueue.read { db in
            try Row.fetchAll(db, sql: """
                SELECT 'plan:' || id AS id, 'plan' AS kind, title, '' AS body FROM plans
                UNION ALL SELECT 'activity:' || id, 'activity', title, COALESCE(details, '') FROM activities
                UNION ALL SELECT 'occurrence:' || o.id, 'occurrence', a.title,
                    o.scheduled_date || ' ' || COALESCE(o.start_time, '') || ' ' || COALESCE(o.end_time, '')
                    FROM schedule_occurrences o JOIN activities a ON a.id=o.activity_id
                UNION ALL SELECT 'execution:' || e.id, 'execution', a.title,
                    o.scheduled_date || ' recorded ' || CAST(e.recorded_at AS TEXT)
                    FROM execution_records e JOIN schedule_occurrences o ON o.id=e.occurrence_id
                    JOIN activities a ON a.id=o.activity_id
                UNION ALL SELECT 'command:' || v.id, 'command',
                    CASE c.kind WHEN 'parent' THEN 'PI-' || printf('%06d', c.sequence_number)
                        ELSE 'PH-' || c.command_date END, COALESCE(v.snapshot_json, v.content_json)
                    FROM operational_command_versions v JOIN operational_commands c ON c.id=v.command_id
                UNION ALL SELECT 'evaluation:' || v.id, 'evaluation',
                    r.title || ' · ' || r.classification, v.responses_json
                    FROM evaluation_versions v JOIN evaluation_rubric_versions r ON r.id=v.rubric_version_id
                UNION ALL SELECT 'document:' || id, 'document', filename, extracted_text
                    FROM local_documents WHERE trashed_at IS NULL
                """).map { row in
                    SearchIndexRecord(id: row["id"], kind: row["kind"], title: row["title"], body: row["body"])
                }
        }
    }

    private static func decodeRecord(_ row: Row) throws -> SearchIndexRecord {
        SearchIndexRecord(id: row["id"], kind: row["kind"], title: row["title"], body: row["body"])
    }
}

public enum SearchRepositoryError: Error, Equatable, LocalizedError {
    case invalidStoredVector
    case sourceChangedDuringIndexing
    public var errorDescription: String? {
        switch self {
        case .invalidStoredVector: "A saved semantic search vector is incomplete."
        case .sourceChangedDuringIndexing: "The source changed while its local search index was being updated."
        }
    }
}
