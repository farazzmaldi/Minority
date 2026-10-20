import CryptoKit
import Foundation
import GRDB

// Foundation documents the shared FileManager operations used here as thread-safe.
public struct DatabaseBackupManager: @unchecked Sendable {
    private let databaseManager: DatabaseManager
    private let fileManager = FileManager.default

    public init(databaseManager: DatabaseManager) {
        self.databaseManager = databaseManager
    }

    public func createBackup(in parentDirectory: URL, label: String = "Minority Backup") throws -> URL {
        try fileManager.createDirectory(at: parentDirectory, withIntermediateDirectories: true)
        let identifier = UUID().uuidString.lowercased()
        let safeLabel = String(label.filter { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == " " || $0 == "-") }.prefix(50))
        let finalURL = parentDirectory.appendingPathComponent(
            "\(safeLabel.isEmpty ? "Minority Backup" : safeLabel) \(Self.timestamp()).minoritybackup",
            isDirectory: true
        )
        let stagingURL = parentDirectory.appendingPathComponent(".minority-backup-\(identifier).tmp", isDirectory: true)
        try fileManager.createDirectory(at: stagingURL, withIntermediateDirectories: false)

        do {
            let backupDatabaseURL = stagingURL.appendingPathComponent("Minority.sqlite")
            let backupQueue = try DatabaseQueue(path: backupDatabaseURL.path)
            try databaseManager.databaseQueue.backup(to: backupQueue)
            let documentFiles = try Self.documentFiles(in: backupQueue, sourceDirectory: documentsDirectory,
                                                       destinationDirectory: stagingURL.appendingPathComponent("Documents", isDirectory: true),
                                                       fileManager: fileManager)
            let migrations = try backupQueue.read { db in
                try String.fetchAll(db, sql: "SELECT identifier FROM grdb_migrations ORDER BY identifier")
            }
            let manifest = BackupManifest(
                format: "minority.backup",
                version: 1,
                createdAt: .now,
                migrations: migrations,
                documents: documentFiles
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(manifest).write(to: stagingURL.appendingPathComponent("manifest.json"), options: .atomic)
            try fileManager.moveItem(at: stagingURL, to: finalURL)
            return finalURL
        } catch let operationError {
            do { try fileManager.removeItem(at: stagingURL) }
            catch let cleanupError {
                throw DatabaseBackupError.stagingCleanupFailed(operationError.localizedDescription, cleanupError.localizedDescription)
            }
            throw operationError
        }
    }

    @discardableResult
    public func restore(from backupURL: URL) throws -> URL {
        let manifest = try Self.readManifest(at: backupURL)
        let backupDatabaseURL = backupURL.appendingPathComponent("Minority.sqlite")
        guard Self.isRegularFile(backupDatabaseURL, fileManager: fileManager) else {
            throw DatabaseBackupError.missingDatabase
        }
        guard backupDatabaseURL.standardizedFileURL != databaseManager.databaseURL.standardizedFileURL else {
            throw DatabaseBackupError.backupIsLiveDatabase
        }

        var readOnlyConfiguration = Configuration()
        readOnlyConfiguration.readonly = true
        let sourceQueue = try DatabaseQueue(path: backupDatabaseURL.path, configuration: readOnlyConfiguration)
        let sourceMigrations = try Self.validateDatabase(sourceQueue, manifest: manifest)
        guard Set(sourceMigrations).isSubset(of: Set(DatabaseManager.supportedMigrationIdentifiers)) else {
            throw DatabaseBackupError.unsupportedDatabaseVersion
        }

        let identifier = UUID().uuidString.lowercased()
        let candidateURL = databaseManager.applicationSupportDirectory.appendingPathComponent("restore-\(identifier).sqlite")
        let candidateQueue = try DatabaseQueue(path: candidateURL.path)
        let stagingDocumentsURL = databaseManager.applicationSupportDirectory.appendingPathComponent("Documents-restore-\(identifier)", isDirectory: true)
        let previousDocumentsURL = databaseManager.applicationSupportDirectory.appendingPathComponent("Documents-previous-\(identifier)", isDirectory: true)

        do {
            try sourceQueue.backup(to: candidateQueue)
            try DatabaseManager.migrateToCurrentVersion(candidateQueue)
            _ = try Self.validateDatabase(candidateQueue, manifest: nil)
            try Self.prepareDocuments(from: backupURL, manifest: manifest, databaseQueue: candidateQueue,
                                      destination: stagingDocumentsURL, fileManager: fileManager)

            let recoveryURL = try createBackup(
                in: databaseManager.applicationSupportDirectory.appendingPathComponent("Recovery", isDirectory: true),
                label: "Minority Recovery"
            )

            let hadExistingDocuments = fileManager.fileExists(atPath: documentsDirectory.path)
            if hadExistingDocuments { try fileManager.moveItem(at: documentsDirectory, to: previousDocumentsURL) }
            do {
                try fileManager.moveItem(at: stagingDocumentsURL, to: documentsDirectory)
                try candidateQueue.backup(to: databaseManager.databaseQueue)
                try DatabaseManager.migrateToCurrentVersion(databaseManager.databaseQueue)
                _ = try Self.validateDatabase(databaseManager.databaseQueue, manifest: nil)
            } catch let restoreError {
                do {
                    let recoveryDatabase = try DatabaseQueue(
                        path: recoveryURL.appendingPathComponent("Minority.sqlite").path,
                        configuration: readOnlyConfiguration
                    )
                    try recoveryDatabase.backup(to: databaseManager.databaseQueue)
                    try DatabaseManager.migrateToCurrentVersion(databaseManager.databaseQueue)
                    if fileManager.fileExists(atPath: documentsDirectory.path) {
                        try fileManager.removeItem(at: documentsDirectory)
                    }
                    if hadExistingDocuments, fileManager.fileExists(atPath: previousDocumentsURL.path) {
                        try fileManager.moveItem(at: previousDocumentsURL, to: documentsDirectory)
                    }
                } catch let rollbackError {
                    throw DatabaseBackupError.restoreAndRollbackFailed(
                        restoreError.localizedDescription,
                        rollbackError.localizedDescription,
                        recoveryURL.path
                    )
                }
                throw restoreError
            }

            if fileManager.fileExists(atPath: previousDocumentsURL.path) {
                try fileManager.removeItem(at: previousDocumentsURL)
            }
            try candidateQueue.close()
            try sourceQueue.close()
            try Self.removeSQLiteFiles(at: candidateURL, fileManager: fileManager)
            return recoveryURL
        } catch let operationError {
            if fileManager.fileExists(atPath: stagingDocumentsURL.path) {
                try fileManager.removeItem(at: stagingDocumentsURL)
            }
            try? candidateQueue.close()
            try? sourceQueue.close()
            if fileManager.fileExists(atPath: candidateURL.path) {
                try Self.removeSQLiteFiles(at: candidateURL, fileManager: fileManager)
            }
            throw operationError
        }
    }

    private var documentsDirectory: URL {
        databaseManager.applicationSupportDirectory.appendingPathComponent("Documents", isDirectory: true)
    }

    private static func documentFiles(
        in databaseQueue: DatabaseQueue,
        sourceDirectory: URL,
        destinationDirectory: URL,
        fileManager: FileManager
    ) throws -> [BackupDocumentFile] {
        let rows = try databaseQueue.read { db -> [(String, Int64)] in
            guard try db.tableExists("local_documents") else { return [] }
            return try Row.fetchAll(db, sql: "SELECT stored_filename, byte_size FROM local_documents")
                .map { ($0["stored_filename"], $0["byte_size"]) }
        }
        guard !rows.isEmpty else { return [] }
        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
        return try rows.map { filename, expectedSize in
            guard Self.isSafeFilename(filename) else { throw DatabaseBackupError.invalidDocumentFilename(filename) }
            let source = sourceDirectory.appendingPathComponent(filename)
            let destination = destinationDirectory.appendingPathComponent(filename)
            guard Self.isRegularFile(source, fileManager: fileManager) else {
                throw DatabaseBackupError.missingDocument(filename)
            }
            try fileManager.copyItem(at: source, to: destination)
            let size = try Self.fileSize(destination, fileManager: fileManager)
            guard size == expectedSize else { throw DatabaseBackupError.documentSizeMismatch(filename) }
            return BackupDocumentFile(filename: filename, byteSize: size, sha256: try Self.sha256(destination))
        }.sorted { $0.filename < $1.filename }
    }

    private static func prepareDocuments(
        from backupURL: URL,
        manifest: BackupManifest,
        databaseQueue: DatabaseQueue,
        destination: URL,
        fileManager: FileManager
    ) throws {
        let requiredFiles = try databaseQueue.read { db -> [(String, Int64)] in
            guard try db.tableExists("local_documents") else { return [] }
            return try Row.fetchAll(db, sql: "SELECT stored_filename, byte_size FROM local_documents")
                .map { ($0["stored_filename"], $0["byte_size"]) }
        }
        let manifestByName = Dictionary(uniqueKeysWithValues: manifest.documents.map { ($0.filename, $0) })
        guard Set(requiredFiles.map(\.0)) == Set(manifestByName.keys) else {
            throw DatabaseBackupError.documentListMismatch
        }
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        for (filename, expectedSize) in requiredFiles {
            guard Self.isSafeFilename(filename), let entry = manifestByName[filename] else {
                throw DatabaseBackupError.invalidDocumentFilename(filename)
            }
            let source = backupURL.appendingPathComponent("Documents", isDirectory: true).appendingPathComponent(filename)
            guard Self.isRegularFile(source, fileManager: fileManager) else { throw DatabaseBackupError.missingDocument(filename) }
            let size = try Self.fileSize(source, fileManager: fileManager)
            guard size == expectedSize, size == entry.byteSize,
                  try Self.sha256(source) == entry.sha256 else {
                throw DatabaseBackupError.documentIntegrityFailure(filename)
            }
            try fileManager.copyItem(at: source, to: destination.appendingPathComponent(filename))
        }
    }

    private static func validateDatabase(_ queue: DatabaseQueue, manifest: BackupManifest?) throws -> [String] {
        try queue.read { db in
            let result = try String.fetchOne(db, sql: "PRAGMA quick_check")
            guard result == "ok" else { throw DatabaseBackupError.databaseIntegrityFailure(result ?? "no result") }
            guard try db.tableExists("grdb_migrations") else { throw DatabaseBackupError.missingMigrationHistory }
            let migrations = try String.fetchAll(db, sql: "SELECT identifier FROM grdb_migrations ORDER BY identifier")
            if let manifest, manifest.migrations.sorted() != migrations.sorted() {
                throw DatabaseBackupError.manifestMismatch
            }
            return migrations
        }
    }

    private static func readManifest(at backupURL: URL) throws -> BackupManifest {
        guard isDirectory(backupURL, fileManager: .default) else { throw DatabaseBackupError.invalidBackupFolder }
        let url = backupURL.appendingPathComponent("manifest.json")
        guard isRegularFile(url, fileManager: .default) else { throw DatabaseBackupError.missingManifest }
        let manifest = try JSONDecoder().decode(BackupManifest.self, from: Data(contentsOf: url))
        guard manifest.format == "minority.backup", manifest.version == 1 else {
            throw DatabaseBackupError.unsupportedBackupFormat
        }
        guard Set(manifest.migrations).isSubset(of: Set(DatabaseManager.supportedMigrationIdentifiers)) else {
            throw DatabaseBackupError.unsupportedDatabaseVersion
        }
        guard Set(manifest.documents.map(\.filename)).count == manifest.documents.count else {
            throw DatabaseBackupError.manifestMismatch
        }
        return manifest
    }

    private static func isSafeFilename(_ filename: String) -> Bool {
        !filename.isEmpty && filename != "." && filename != ".." &&
            URL(fileURLWithPath: filename).lastPathComponent == filename &&
            !filename.contains("/") && !filename.contains("\\")
    }

    private static func isDirectory(_ url: URL, fileManager: FileManager) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else { return false }
        return values.isDirectory == true && values.isSymbolicLink != true
    }

    private static func isRegularFile(_ url: URL, fileManager: FileManager) -> Bool {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path) else { return false }
        return attributes[.type] as? FileAttributeType == .typeRegular
    }

    private static func fileSize(_ url: URL, fileManager: FileManager) throws -> Int64 {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        return (attributes[.size] as? NSNumber)?.int64Value ?? -1
    }

    private static func sha256(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func removeSQLiteFiles(at url: URL, fileManager: FileManager) throws {
        for suffix in ["", "-wal", "-shm"] {
            let file = URL(fileURLWithPath: url.path + suffix)
            if fileManager.fileExists(atPath: file.path) { try fileManager.removeItem(at: file) }
        }
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
        return formatter.string(from: .now)
    }
}

private struct BackupManifest: Codable {
    let format: String
    let version: Int
    let createdAt: Date
    let migrations: [String]
    let documents: [BackupDocumentFile]
}

private struct BackupDocumentFile: Codable {
    let filename: String
    let byteSize: Int64
    let sha256: String
}

public enum DatabaseBackupError: Error, LocalizedError {
    case stagingCleanupFailed(String, String)
    case invalidBackupFolder
    case missingManifest
    case unsupportedBackupFormat
    case unsupportedDatabaseVersion
    case missingDatabase
    case backupIsLiveDatabase
    case missingMigrationHistory
    case manifestMismatch
    case databaseIntegrityFailure(String)
    case invalidDocumentFilename(String)
    case missingDocument(String)
    case documentSizeMismatch(String)
    case documentListMismatch
    case documentIntegrityFailure(String)
    case restoreAndRollbackFailed(String, String, String)

    public var errorDescription: String? {
        switch self {
        case let .stagingCleanupFailed(operation, cleanup):
            "Backup operation failed: \(operation). Temporary backup cleanup also failed: \(cleanup)."
        case .invalidBackupFolder: "The selected folder is not a Minority backup."
        case .missingManifest: "The backup manifest is missing."
        case .unsupportedBackupFormat: "This Minority backup format is not supported."
        case .unsupportedDatabaseVersion: "The backup contains database migrations this app does not support."
        case .missingDatabase: "The backup database is missing."
        case .backupIsLiveDatabase: "Select a backup folder, not the active Minority database."
        case .missingMigrationHistory: "The backup database has no migration history."
        case .manifestMismatch: "The backup manifest does not match the database."
        case let .databaseIntegrityFailure(result): "The backup database failed its integrity check: \(result)."
        case let .invalidDocumentFilename(filename): "The backup contains an invalid document filename: \(filename)."
        case let .missingDocument(filename): "The backup is missing document: \(filename)."
        case let .documentSizeMismatch(filename): "The stored size does not match document: \(filename)."
        case .documentListMismatch: "The backup document list does not match its database."
        case let .documentIntegrityFailure(filename): "The document failed its integrity check: \(filename)."
        case let .restoreAndRollbackFailed(restore, rollback, recoveryPath):
            "Restore failed: \(restore). Automatic rollback also failed: \(rollback). Use the recovery backup at \(recoveryPath)."
        }
    }
}
