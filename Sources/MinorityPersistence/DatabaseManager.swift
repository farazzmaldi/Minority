import Foundation
import GRDB

public struct DatabaseManager: Sendable {
    public let databaseQueue: DatabaseQueue
    public let applicationSupportDirectory: URL
    public let databaseURL: URL

    public init(databaseURL: URL) throws {
        applicationSupportDirectory = databaseURL.deletingLastPathComponent()
        self.databaseURL = databaseURL
        try FileManager.default.createDirectory(at: applicationSupportDirectory, withIntermediateDirectories: true)

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

    public static var supportedMigrationIdentifiers: [String] { migrator.migrations }

    public static func migrateToCurrentVersion(_ databaseQueue: DatabaseQueue) throws {
        try migrator.migrate(databaseQueue)
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
        migrator.registerMigration("objectives_v1") { db in
            try db.execute(sql: """
                CREATE TABLE objectives (
                    id TEXT PRIMARY KEY NOT NULL,
                    title TEXT NOT NULL CHECK (length(trim(title)) > 0),
                    details TEXT
                )
                """)
            try db.execute(sql: """
                CREATE TABLE plan_objectives (
                    id TEXT PRIMARY KEY NOT NULL,
                    plan_id TEXT NOT NULL REFERENCES plans(id) ON DELETE CASCADE,
                    objective_id TEXT NOT NULL REFERENCES objectives(id) ON DELETE RESTRICT,
                    UNIQUE (plan_id, objective_id)
                )
                """)
        }
        migrator.registerMigration("commands_v1") { db in
            try db.execute(sql: """
                CREATE TABLE operational_commands (
                    id TEXT PRIMARY KEY NOT NULL,
                    kind TEXT NOT NULL CHECK (kind IN ('parent', 'daily')),
                    sequence_number INTEGER,
                    command_date TEXT,
                    created_at REAL NOT NULL,
                    CHECK (
                        (kind = 'parent' AND sequence_number IS NOT NULL AND sequence_number > 0 AND command_date IS NULL)
                        OR
                        (kind = 'daily' AND sequence_number IS NULL AND command_date IS NOT NULL
                            AND command_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
                            AND date(command_date, '+0 days') = command_date)
                    )
                )
                """)
            try db.execute(sql: "CREATE UNIQUE INDEX operational_commands_parent_number ON operational_commands(sequence_number) WHERE kind = 'parent'")
            try db.execute(sql: "CREATE UNIQUE INDEX operational_commands_daily_date ON operational_commands(command_date) WHERE kind = 'daily'")
            try db.execute(sql: """
                CREATE TABLE operational_command_versions (
                    id TEXT PRIMARY KEY NOT NULL,
                    command_id TEXT NOT NULL REFERENCES operational_commands(id) ON DELETE RESTRICT,
                    version_number INTEGER NOT NULL CHECK (version_number > 0),
                    state TEXT NOT NULL CHECK (state IN ('draft', 'published', 'superseded', 'withdrawn')),
                    content_json TEXT NOT NULL,
                    snapshot_json TEXT,
                    created_at REAL NOT NULL,
                    published_at REAL,
                    replaced_by_version_id TEXT REFERENCES operational_command_versions(id) ON DELETE RESTRICT,
                    UNIQUE (command_id, version_number),
                    CHECK (
                        (state = 'draft' AND snapshot_json IS NULL AND published_at IS NULL)
                        OR
                        (state != 'draft' AND snapshot_json IS NOT NULL AND published_at IS NOT NULL)
                    )
                )
                """)
            try db.execute(sql: "CREATE UNIQUE INDEX operational_command_one_published_version ON operational_command_versions(command_id) WHERE state = 'published'")
            try db.execute(sql: """
                CREATE TRIGGER operational_command_versions_immutable
                BEFORE UPDATE ON operational_command_versions
                WHEN OLD.state != 'draft' AND (
                    NEW.command_id != OLD.command_id OR
                    NEW.version_number != OLD.version_number OR
                    NEW.content_json != OLD.content_json OR
                    NEW.snapshot_json != OLD.snapshot_json OR
                    NEW.created_at != OLD.created_at OR
                    NEW.published_at != OLD.published_at OR
                    (NEW.state = OLD.state AND NEW.replaced_by_version_id IS NOT OLD.replaced_by_version_id) OR
                    (NEW.state != OLD.state AND NOT (
                        OLD.state = 'published' AND NEW.state IN ('superseded', 'withdrawn')
                    ))
                )
                BEGIN
                    SELECT RAISE(ABORT, 'published command versions are immutable');
                END
                """)
            try db.execute(sql: """
                CREATE TRIGGER operational_command_versions_no_delete
                BEFORE DELETE ON operational_command_versions
                WHEN OLD.state != 'draft'
                BEGIN
                    SELECT RAISE(ABORT, 'published command versions cannot be deleted');
                END
                """)
            try db.execute(sql: """
                CREATE TRIGGER operational_commands_no_update
                BEFORE UPDATE ON operational_commands
                WHEN NOT (
                    OLD.kind = 'daily'
                    AND NEW.id = OLD.id
                    AND NEW.kind = OLD.kind
                    AND NEW.sequence_number IS OLD.sequence_number
                    AND NEW.created_at = OLD.created_at
                    AND NEW.command_date IS NOT OLD.command_date
                    AND EXISTS (
                        SELECT 1 FROM operational_command_versions
                        WHERE command_id = OLD.id AND state = 'draft'
                    )
                    AND NOT EXISTS (
                        SELECT 1 FROM operational_command_versions
                        WHERE command_id = OLD.id AND state != 'draft'
                    )
                )
                BEGIN
                    SELECT RAISE(ABORT, 'only a draft daily command date can be changed');
                END
                """)
            try db.execute(sql: """
                CREATE TRIGGER operational_commands_no_delete
                BEFORE DELETE ON operational_commands
                BEGIN
                    SELECT RAISE(ABORT, 'operational command identity cannot be deleted');
                END
                """)
        }
        migrator.registerMigration("evaluation_v1") { db in
            try db.execute(sql: """
                CREATE TABLE evaluation_rubrics (
                    id TEXT PRIMARY KEY NOT NULL,
                    title TEXT NOT NULL CHECK (length(trim(title)) > 0),
                    created_at REAL NOT NULL
                )
                """)
            try db.execute(sql: """
                CREATE TABLE evaluation_rubric_versions (
                    id TEXT PRIMARY KEY NOT NULL,
                    rubric_id TEXT NOT NULL REFERENCES evaluation_rubrics(id) ON DELETE RESTRICT,
                    version_number INTEGER NOT NULL CHECK (version_number > 0),
                    title TEXT NOT NULL CHECK (length(trim(title)) > 0),
                    classification TEXT NOT NULL CHECK (length(trim(classification)) > 0),
                    criteria_json TEXT NOT NULL,
                    created_at REAL NOT NULL,
                    UNIQUE (rubric_id, version_number)
                )
                """)
            try db.execute(sql: """
                CREATE TABLE evaluations (
                    id TEXT PRIMARY KEY NOT NULL,
                    execution_record_id TEXT NOT NULL UNIQUE
                        REFERENCES execution_records(id) ON DELETE RESTRICT,
                    created_at REAL NOT NULL
                )
                """)
            try db.execute(sql: """
                CREATE TABLE evaluation_versions (
                    id TEXT PRIMARY KEY NOT NULL,
                    evaluation_id TEXT NOT NULL REFERENCES evaluations(id) ON DELETE RESTRICT,
                    version_number INTEGER NOT NULL CHECK (version_number > 0),
                    rubric_version_id TEXT NOT NULL REFERENCES evaluation_rubric_versions(id) ON DELETE RESTRICT,
                    responses_json TEXT NOT NULL,
                    created_at REAL NOT NULL,
                    UNIQUE (evaluation_id, version_number)
                )
                """)
            try db.execute(sql: """
                CREATE TRIGGER evaluation_rubric_versions_immutable_update
                BEFORE UPDATE ON evaluation_rubric_versions
                BEGIN SELECT RAISE(ABORT, 'evaluation rubric versions are immutable'); END
                """)
            try db.execute(sql: """
                CREATE TRIGGER evaluation_rubric_versions_immutable_delete
                BEFORE DELETE ON evaluation_rubric_versions
                BEGIN SELECT RAISE(ABORT, 'evaluation rubric versions cannot be deleted'); END
                """)
            try db.execute(sql: """
                CREATE TRIGGER evaluation_versions_immutable_update
                BEFORE UPDATE ON evaluation_versions
                BEGIN SELECT RAISE(ABORT, 'evaluation versions are immutable'); END
                """)
            try db.execute(sql: """
                CREATE TRIGGER evaluation_versions_immutable_delete
                BEFORE DELETE ON evaluation_versions
                BEGIN SELECT RAISE(ABORT, 'evaluation versions cannot be deleted'); END
                """)
            try db.execute(sql: """
                CREATE TRIGGER evaluations_no_update
                BEFORE UPDATE ON evaluations
                BEGIN SELECT RAISE(ABORT, 'evaluation identity cannot be changed'); END
                """)
            try db.execute(sql: """
                CREATE TRIGGER evaluations_no_delete
                BEFORE DELETE ON evaluations
                BEGIN SELECT RAISE(ABORT, 'evaluation identity cannot be deleted'); END
                """)
        }
        migrator.registerMigration("documents_v1") { db in
            try db.execute(sql: """
                CREATE TABLE local_documents (
                    id TEXT PRIMARY KEY NOT NULL,
                    filename TEXT NOT NULL CHECK (length(trim(filename)) > 0),
                    stored_filename TEXT NOT NULL UNIQUE,
                    media_type TEXT NOT NULL,
                    byte_size INTEGER NOT NULL CHECK (byte_size >= 0),
                    imported_at REAL NOT NULL,
                    extracted_text TEXT NOT NULL DEFAULT '',
                    extraction_error TEXT,
                    trashed_at REAL
                )
                """)
            try db.execute(sql: "CREATE INDEX local_documents_imported_at ON local_documents(imported_at DESC)")
        }
        migrator.registerMigration("search_v1") { db in
            try db.execute(sql: """
                CREATE TABLE search_index (
                    id TEXT PRIMARY KEY NOT NULL,
                    kind TEXT NOT NULL,
                    title TEXT NOT NULL,
                    body TEXT NOT NULL,
                    fingerprint TEXT NOT NULL,
                    indexed_at REAL NOT NULL
                )
                """)
            try db.execute(sql: """
                CREATE VIRTUAL TABLE search_fts USING fts5(
                    record_id UNINDEXED,
                    title,
                    body,
                    tokenize = 'unicode61 remove_diacritics 2'
                )
                """)
            try db.execute(sql: """
                CREATE TABLE semantic_vectors (
                    record_id TEXT NOT NULL REFERENCES search_index(id) ON DELETE CASCADE,
                    chunk_index INTEGER NOT NULL CHECK (chunk_index >= 0),
                    model_identifier TEXT NOT NULL,
                    model_revision INTEGER NOT NULL,
                    dimension INTEGER NOT NULL CHECK (dimension > 0),
                    vector BLOB NOT NULL,
                    PRIMARY KEY (record_id, chunk_index, model_identifier, model_revision)
                )
                """)
        }
        return migrator
    }()
}
