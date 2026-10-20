import Foundation
import GRDB

public struct LocalDocument: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let filename: String
    public let storedFilename: String
    public let mediaType: String
    public let byteSize: Int64
    public let importedAt: Date
    public let extractedText: String
    public let extractionError: String?
    public let trashedAt: Date?
}

public struct DocumentRepository {
    private let databaseQueue: DatabaseQueue
    private let documentsDirectory: URL

    public init(databaseQueue: DatabaseQueue, applicationSupportDirectory: URL) {
        self.databaseQueue = databaseQueue
        documentsDirectory = applicationSupportDirectory.appendingPathComponent("Documents", isDirectory: true)
    }

    @discardableResult
    public func add(
        from sourceURL: URL,
        mediaType: String,
        extractedText: String,
        extractionError: String? = nil,
        importedAt: Date = .now
    ) throws -> LocalDocument {
        try FileManager.default.createDirectory(at: documentsDirectory, withIntermediateDirectories: true)
        let id = UUID()
        let fileExtension = sourceURL.pathExtension
            .lowercased()
            .filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
        let storedFilename = fileExtension.isEmpty ? id.uuidString.lowercased() : "\(id.uuidString.lowercased()).\(fileExtension)"
        let destinationURL = documentsDirectory.appendingPathComponent(storedFilename)
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: destinationURL.path)
            let document = LocalDocument(
                id: id,
                filename: sourceURL.lastPathComponent,
                storedFilename: storedFilename,
                mediaType: mediaType,
                byteSize: (attributes[.size] as? NSNumber)?.int64Value ?? 0,
                importedAt: importedAt,
                extractedText: extractedText,
                extractionError: extractionError,
                trashedAt: nil
            )
            try databaseQueue.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO local_documents
                            (id, filename, stored_filename, media_type, byte_size, imported_at, extracted_text, extraction_error)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                    arguments: [
                        id.uuidString.lowercased(), document.filename, storedFilename, mediaType,
                        document.byteSize, importedAt.timeIntervalSince1970, extractedText, extractionError
                    ]
                )
            }
            return document
        } catch let databaseError {
            do { try FileManager.default.removeItem(at: destinationURL) }
            catch let cleanupError {
                throw DocumentRepositoryError.cleanupFailed(
                    storedFilename,
                    "\(cleanupError.localizedDescription); original database error: \(databaseError.localizedDescription)"
                )
            }
            throw databaseError
        }
    }

    public func documents(includeTrash: Bool = false) throws -> [LocalDocument] {
        try databaseQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                    SELECT id, filename, stored_filename, media_type, byte_size, imported_at,
                           extracted_text, extraction_error, trashed_at
                    FROM local_documents
                    WHERE (? OR trashed_at IS NULL)
                    ORDER BY imported_at DESC, filename COLLATE NOCASE, id
                    """,
                arguments: [includeTrash]
            )
            return try rows.map(Self.decode)
        }
    }

    public func document(id: UUID) throws -> LocalDocument? {
        try databaseQueue.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: """
                    SELECT id, filename, stored_filename, media_type, byte_size, imported_at,
                           extracted_text, extraction_error, trashed_at
                    FROM local_documents WHERE id = ?
                    """,
                arguments: [id.uuidString.lowercased()]
            ) else { return nil }
            return try Self.decode(row)
        }
    }

    public func fileURL(for document: LocalDocument) -> URL {
        documentsDirectory.appendingPathComponent(document.storedFilename)
    }

    public func moveToTrash(id: UUID, at date: Date = .now) throws {
        try databaseQueue.write { db in
            try db.execute(
                sql: "UPDATE local_documents SET trashed_at = ? WHERE id = ? AND trashed_at IS NULL",
                arguments: [date.timeIntervalSince1970, id.uuidString.lowercased()]
            )
            guard db.changesCount == 1 else { throw DocumentRepositoryError.documentNotFound }
        }
    }

    public func restore(id: UUID) throws {
        try databaseQueue.write { db in
            try db.execute(
                sql: "UPDATE local_documents SET trashed_at = NULL WHERE id = ? AND trashed_at IS NOT NULL",
                arguments: [id.uuidString.lowercased()]
            )
            guard db.changesCount == 1 else { throw DocumentRepositoryError.documentNotInTrash }
        }
    }

    private static func decode(_ row: Row) throws -> LocalDocument {
        guard let id = UUID(uuidString: row["id"]) else { throw DocumentRepositoryError.invalidStoredIdentifier }
        return LocalDocument(
            id: id,
            filename: row["filename"],
            storedFilename: row["stored_filename"],
            mediaType: row["media_type"],
            byteSize: row["byte_size"],
            importedAt: Date(timeIntervalSince1970: row["imported_at"]),
            extractedText: row["extracted_text"],
            extractionError: row["extraction_error"],
            trashedAt: (row["trashed_at"] as Double?).map(Date.init(timeIntervalSince1970:))
        )
    }
}

public enum DocumentRepositoryError: Error, Equatable, LocalizedError {
    case documentNotFound
    case documentNotInTrash
    case invalidStoredIdentifier
    case cleanupFailed(String, String)

    public var errorDescription: String? {
        switch self {
        case .documentNotFound: "The document was not found or is already in Trash."
        case .documentNotInTrash: "The document is not in Trash."
        case .invalidStoredIdentifier: "A stored document has an invalid identifier."
        case let .cleanupFailed(filename, details): "The document record could not be saved and its copied file could not be removed (\(filename)): \(details)"
        }
    }
}
