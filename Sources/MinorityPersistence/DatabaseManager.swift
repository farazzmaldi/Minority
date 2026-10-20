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

        try Self.migrator.migrate(databaseQueue)
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

    private static let migrator: DatabaseMigrator = {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("foundation") { _ in }
        migrator.registerMigration("planning_v1") { db in
            try db.execute(sql: """
                CREATE TABLE plans (
                    id TEXT PRIMARY KEY NOT NULL,
                    title TEXT NOT NULL CHECK (length(trim(title)) > 0),
                    start_date TEXT NOT NULL CHECK (
                        start_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
                        AND substr(start_date, 1, 4) BETWEEN '0001' AND '9999'
                        AND date(start_date, '+0 days') = start_date
                    ),
                    end_date TEXT NOT NULL CHECK (
                        end_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
                        AND substr(end_date, 1, 4) BETWEEN '0001' AND '9999'
                        AND date(end_date, '+0 days') = end_date
                    ),
                    CHECK (start_date <= end_date)
                )
                """)
            try db.execute(sql: """
                CREATE TABLE activities (
                    id TEXT PRIMARY KEY NOT NULL,
                    title TEXT NOT NULL CHECK (length(trim(title)) > 0),
                    details TEXT
                )
                """)
            try db.execute(sql: """
                CREATE TABLE plan_activities (
                    id TEXT PRIMARY KEY NOT NULL,
                    plan_id TEXT NOT NULL REFERENCES plans(id) ON DELETE CASCADE,
                    activity_id TEXT NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
                    UNIQUE (plan_id, activity_id)
                )
                """)
            try db.execute(sql: """
                CREATE TABLE schedule_occurrences (
                    id TEXT PRIMARY KEY NOT NULL,
                    activity_id TEXT NOT NULL REFERENCES activities(id) ON DELETE RESTRICT,
                    scheduled_date TEXT NOT NULL CHECK (
                        scheduled_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
                        AND substr(scheduled_date, 1, 4) BETWEEN '0001' AND '9999'
                        AND date(scheduled_date, '+0 days') = scheduled_date
                    ),
                    start_time TEXT,
                    end_time TEXT,
                    priority INTEGER,
                    CHECK (
                        (start_time IS NULL AND end_time IS NULL)
                        OR (
                            start_time IS NOT NULL AND end_time IS NOT NULL
                            AND length(start_time) = 5
                            AND start_time GLOB '[0-2][0-9]:[0-5][0-9]'
                            AND substr(start_time, 1, 2) BETWEEN '00' AND '23'
                            AND length(end_time) = 5
                            AND end_time GLOB '[0-2][0-9]:[0-5][0-9]'
                            AND substr(end_time, 1, 2) BETWEEN '00' AND '23'
                            AND end_time > start_time
                        )
                    )
                )
                """)
        }
        migrator.registerMigration("execution_v1") { db in
            try db.execute(sql: """
                CREATE TABLE execution_records (
                    id TEXT PRIMARY KEY NOT NULL,
                    occurrence_id TEXT NOT NULL UNIQUE
                        REFERENCES schedule_occurrences(id) ON DELETE RESTRICT,
                    recorded_at REAL NOT NULL
                )
                """)
        }
        return migrator
    }()
}
