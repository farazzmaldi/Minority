import Foundation
import GRDB

public struct DatabaseManager {
    public let databaseQueue: DatabaseQueue

    public init(databaseURL: URL) throws {
        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        databaseQueue = try DatabaseQueue(path: databaseURL.path)

        var migrator = DatabaseMigrator()
        migrator.registerMigration("foundation") { _ in }
        try migrator.migrate(databaseQueue)
    }

    public static func applicationDatabase() throws -> DatabaseManager {
        let supportDirectory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let applicationDirectory = supportDirectory.appendingPathComponent("Minority", isDirectory: true)
        let databaseURL = applicationDirectory.appendingPathComponent("minority.sqlite")
        return try DatabaseManager(databaseURL: databaseURL)
    }
}
