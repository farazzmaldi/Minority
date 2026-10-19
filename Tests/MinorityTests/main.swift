import Foundation
import GRDB
import MinorityPersistence

@main
enum DatabaseManagerChecks {
    static func main() throws {
        try checkDatabaseInitializationReadWriteAndMigrationIdempotency()
        try checkInitializationFailurePreservesExistingData()
        try checkTransactionRollbackAndErrorPropagation()
        print("Persistence checks passed")
    }

    private static func checkDatabaseInitializationReadWriteAndMigrationIdempotency() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let databaseURL = directory.appendingPathComponent("test.sqlite")
        let manager = try DatabaseManager(databaseURL: databaseURL)

        try manager.databaseQueue.write { db in
            try db.execute(sql: "CREATE TABLE records (id INTEGER PRIMARY KEY, value TEXT NOT NULL)")
            try db.execute(sql: "INSERT INTO records (value) VALUES (?)", arguments: ["persisted"])
        }

        let value = try manager.databaseQueue.read { db in
            try String.fetchOne(db, sql: "SELECT value FROM records WHERE id = 1")
        }
        try require(value == "persisted", "Database write/read did not preserve the value")

        _ = try DatabaseManager(databaseURL: databaseURL)
        _ = try DatabaseManager(databaseURL: databaseURL)

        let appliedMigrations = try manager.databaseQueue.read { db in
            try String.fetchAll(db, sql: "SELECT identifier FROM grdb_migrations ORDER BY identifier")
        }
        try require(appliedMigrations == ["foundation"], "Migration was not applied exactly once")
    }

    private static func checkInitializationFailurePreservesExistingData() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let obstructionURL = directory.appendingPathComponent("existing-data")
        let originalContents = Data("preserve this data".utf8)
        try originalContents.write(to: obstructionURL)

        let databaseURL = obstructionURL.appendingPathComponent("test.sqlite")
        do {
            _ = try DatabaseManager(databaseURL: databaseURL)
            throw CheckFailure(description: "Database initialization unexpectedly succeeded")
        } catch is CheckFailure {
            throw CheckFailure(description: "Database initialization unexpectedly succeeded")
        } catch {
            let currentContents = try Data(contentsOf: obstructionURL)
            try require(currentContents == originalContents, "Initialization failure changed existing data")
        }
    }

    private static func checkTransactionRollbackAndErrorPropagation() throws {
        enum ExpectedError: Error { case rollback }

        let manager = try makeDatabaseManager()
        try manager.databaseQueue.write { db in
            try db.execute(sql: "CREATE TABLE values_table (value INTEGER NOT NULL)")
        }

        do {
            try manager.databaseQueue.write { db in
                try db.execute(sql: "INSERT INTO values_table (value) VALUES (1)")
                throw ExpectedError.rollback
            }
            throw CheckFailure(description: "Transaction error was not propagated")
        } catch ExpectedError.rollback {
            // Expected: the transaction aborts and the original error reaches the caller.
        }

        let rowCount = try manager.databaseQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM values_table")
        }
        try require(rowCount == 0, "Failed transaction did not roll back")

        do {
            try manager.databaseQueue.write { db in
                try db.execute(sql: "INSERT INTO missing_table VALUES (1)")
            }
            throw CheckFailure(description: "SQLite error was not propagated")
        } catch is DatabaseError {
            // Expected: GRDB propagates the SQLite failure.
        }
    }

    private static func makeDatabaseManager() throws -> DatabaseManager {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        return try DatabaseManager(databaseURL: directory.appendingPathComponent("test.sqlite"))
    }

    private static func require(_ condition: Bool, _ message: String) throws {
        if !condition { throw CheckFailure(description: message) }
    }
}

private struct CheckFailure: Error, CustomStringConvertible {
    let description: String
}
