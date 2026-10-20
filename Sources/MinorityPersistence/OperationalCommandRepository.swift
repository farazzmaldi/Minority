import Foundation
import GRDB

public struct OperationalCommandRepository {
    private let databaseQueue: DatabaseQueue

    public init(databaseQueue: DatabaseQueue) {
        self.databaseQueue = databaseQueue
    }


    @discardableResult
    public func createParentDraft(content: OperationalCommandDraftContent) throws -> OperationalCommandVersion {
        guard content.items.isEmpty else { throw OperationalCommandValidationError.wrongTargetKind }
        return try createDraft(kind: .parent, date: nil, content: content)
    }

    @discardableResult
    public func createDailyDraft(date: String, content: OperationalCommandDraftContent) throws -> OperationalCommandVersion {
        try Plan.validateDate(date)
        guard content.targets.isEmpty, content.effectiveDate == nil else {
            throw OperationalCommandValidationError.wrongTargetKind
        }
        return try createDraft(kind: .daily, date: date, content: content)
    }

    @discardableResult
    public func updateDraft(
        versionID: UUID,
        content: OperationalCommandDraftContent,
        dailyDate: String? = nil
    ) throws -> OperationalCommandVersion {
        try databaseQueue.write { db in
            guard let row = try commandVersionRow(id: versionID, in: db), row["state"] as String == "draft" else {
                throw OperationalCommandValidationError.versionIsNotDraft
            }
            let kind = OperationalCommandKind(rawValue: row["kind"] as String)!
            guard (kind == .parent && content.items.isEmpty) || (kind == .daily && content.targets.isEmpty) else {
                throw OperationalCommandValidationError.wrongTargetKind
            }
            if kind == .daily, content.effectiveDate != nil {
                throw OperationalCommandValidationError.wrongTargetKind
            }
            if kind == .daily {
                guard let dailyDate else { throw OperationalCommandValidationError.wrongTargetKind }
                try Plan.validateDate(dailyDate)
                if dailyDate != (row["command_date"] as String?) {
                    try db.execute(
                        sql: "UPDATE operational_commands SET command_date = ? WHERE id = ?",
                        arguments: [dailyDate, row["command_id"] as String]
                    )
                }
            } else if dailyDate != nil {
                throw OperationalCommandValidationError.wrongTargetKind
            }
            try db.execute(
                sql: "UPDATE operational_command_versions SET content_json = ? WHERE id = ?",
                arguments: [try encode(content), uuid(versionID)]
            )
            return try readVersion(id: versionID, in: db)
        }
    }

    @discardableResult
    public func createRevision(of versionID: UUID) throws -> OperationalCommandVersion {
        try databaseQueue.write { db in
            guard let source = try commandVersionRow(id: versionID, in: db), source["state"] as String == "published" else {
                throw OperationalCommandValidationError.versionIsNotCurrentPublished
            }
            let commandID: String = source["command_id"]
            let current = try Row.fetchOne(
                db,
                sql: "SELECT id FROM operational_command_versions WHERE command_id = ? AND state = 'published'",
                arguments: [commandID]
            )
            guard current?["id"] as String? == uuid(versionID) else {
                throw OperationalCommandValidationError.versionIsNotCurrentPublished
            }
            let draftCount = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM operational_command_versions WHERE command_id = ? AND state = 'draft'",
                arguments: [commandID]
            ) ?? 0
            guard draftCount == 0 else { throw OperationalCommandValidationError.draftAlreadyExists }

            let nextVersion = (source["version_number"] as Int) + 1
            let draftID = UUID()
            try db.execute(
                sql: """
                    INSERT INTO operational_command_versions
                        (id, command_id, version_number, state, content_json, snapshot_json, created_at, published_at)
                    VALUES (?, ?, ?, 'draft', ?, NULL, ?, NULL)
                    """,
                arguments: [uuid(draftID), commandID, nextVersion, source["content_json"] as String, Date.now.timeIntervalSince1970]
            )
            return try readVersion(id: draftID, in: db)
        }
    }

    @discardableResult
    public func publish(versionID: UUID) throws -> OperationalCommandVersion {
        try databaseQueue.write { db in
            guard let draft = try commandVersionRow(id: versionID, in: db), draft["state"] as String == "draft" else {
                throw OperationalCommandValidationError.versionIsNotDraft
            }
            let commandID: String = draft["command_id"]
            let kind = OperationalCommandKind(rawValue: draft["kind"] as String)!
            let commandDate: String? = draft["command_date"]
            let number = try commandNumber(kind: kind, commandID: commandID, in: db)
            let content = try decode(OperationalCommandDraftContent.self, from: draft["content_json"] as String)
            let snapshot = try makeSnapshot(
                kind: kind,
                number: number,
                versionNumber: draft["version_number"],
                date: commandDate,
                content: content,
                in: db
            )
            let snapshotJSON = try encode(snapshot)
            let previous = try Row.fetchOne(
                db,
                sql: "SELECT id FROM operational_command_versions WHERE command_id = ? AND state = 'published'",
                arguments: [commandID]
            )
            if let previousID = previous?["id"] as String? {
                try db.execute(
                    sql: "UPDATE operational_command_versions SET state = 'superseded', replaced_by_version_id = ? WHERE id = ?",
                    arguments: [uuid(versionID), previousID]
                )
            }
            try db.execute(
                sql: """
                    UPDATE operational_command_versions
                    SET state = 'published', snapshot_json = ?, published_at = ?
                    WHERE id = ? AND state = 'draft'
                    """,
                arguments: [snapshotJSON, Date.now.timeIntervalSince1970, uuid(versionID)]
            )
            return try readVersion(id: versionID, in: db)
        }
    }

    public func withdraw(versionID: UUID) throws {
        try databaseQueue.write { db in
            guard let row = try commandVersionRow(id: versionID, in: db), row["state"] as String == "published" else {
                throw OperationalCommandValidationError.versionIsNotCurrentPublished
            }
            let currentID = try String.fetchOne(
                db,
                sql: "SELECT id FROM operational_command_versions WHERE command_id = ? AND state = 'published'",
                arguments: [row["command_id"] as String]
            )
            guard currentID == uuid(versionID) else {
                throw OperationalCommandValidationError.versionIsNotCurrentPublished
            }
            try db.execute(
                sql: "UPDATE operational_command_versions SET state = 'withdrawn' WHERE id = ?",
                arguments: [uuid(versionID)]
            )
        }
    }

    public func commands(kind: OperationalCommandKind) throws -> [OperationalCommand] {
        try databaseQueue.read { db in
            try Row.fetchAll(
                db,
                sql: "SELECT id, kind, sequence_number, command_date, created_at FROM operational_commands WHERE kind = ? ORDER BY COALESCE(command_date, ''), sequence_number DESC, created_at DESC",
                arguments: [kind.rawValue]
            ).map { try readCommand(row: $0, in: db) }
        }
    }

    public func versions(forCommandID commandID: UUID) throws -> [OperationalCommandVersion] {
        try databaseQueue.read { db in
            try String.fetchAll(
                db,
                sql: "SELECT id FROM operational_command_versions WHERE command_id = ? ORDER BY version_number DESC",
                arguments: [uuid(commandID)]
            ).map { rawID in
                guard let id = UUID(uuidString: rawID) else {
                    throw OperationalCommandValidationError.corruptedStoredContent
                }
                return try readVersion(id: id, in: db)
            }
        }
    }

    public func version(id: UUID) throws -> OperationalCommandVersion? {
        try databaseQueue.read { db in
            guard try commandVersionRow(id: id, in: db) != nil else { return nil }
            return try readVersion(id: id, in: db)
        }
    }

    private func createDraft(
        kind: OperationalCommandKind,
        date: String?,
        content: OperationalCommandDraftContent
    ) throws -> OperationalCommandVersion {
        try databaseQueue.write { db in
            let commandID = UUID()
            let versionID = UUID()
            let now = Date.now.timeIntervalSince1970
            if kind == .daily {
                try db.execute(
                    sql: "INSERT INTO operational_commands (id, kind, sequence_number, command_date, created_at) VALUES (?, 'daily', NULL, ?, ?)",
                    arguments: [uuid(commandID), date, now]
                )
            } else {
                let nextNumber = try Int.fetchOne(
                    db,
                    sql: "SELECT COALESCE(MAX(sequence_number), 0) + 1 FROM operational_commands WHERE kind = 'parent'"
                ) ?? 1
                try db.execute(
                    sql: "INSERT INTO operational_commands (id, kind, sequence_number, command_date, created_at) VALUES (?, 'parent', ?, NULL, ?)",
                    arguments: [uuid(commandID), nextNumber, now]
                )
            }
            try db.execute(
                sql: """
                    INSERT INTO operational_command_versions
                        (id, command_id, version_number, state, content_json, snapshot_json, created_at, published_at)
                    VALUES (?, ?, 1, 'draft', ?, NULL, ?, NULL)
                    """,
                arguments: [uuid(versionID), uuid(commandID), try encode(content), now]
            )
            return try readVersion(id: versionID, in: db)
        }
    }

    private func makeSnapshot(
        kind: OperationalCommandKind,
        number: String,
        versionNumber: Int,
        date: String?,
        content: OperationalCommandDraftContent,
        in db: Database
    ) throws -> OperationalCommandSnapshot {
        var targets: [OperationalCommandSnapshotTarget] = []
        for target in content.targets {
            let row: Row?
            switch target.kind {
            case .plan:
                row = try Row.fetchOne(db, sql: "SELECT title, NULL AS details, start_date, end_date FROM plans WHERE id = ?", arguments: [uuid(target.targetID)])
            case .activity:
                row = try Row.fetchOne(db, sql: "SELECT title, details, NULL AS start_date, NULL AS end_date FROM activities WHERE id = ?", arguments: [uuid(target.targetID)])
            case .objective:
                row = try Row.fetchOne(db, sql: "SELECT title, details, NULL AS start_date, NULL AS end_date FROM objectives WHERE id = ?", arguments: [uuid(target.targetID)])
            }
            guard let row else { throw OperationalCommandValidationError.missingReference }
            targets.append(.init(
                kind: target.kind,
                targetID: target.targetID,
                title: row["title"],
                details: row["details"],
                startDate: row["start_date"],
                endDate: row["end_date"]
            ))
        }

        var items: [OperationalCommandSnapshotItem] = []
        if kind == .daily {
            guard let date else { throw OperationalCommandValidationError.corruptedStoredContent }
            for (index, item) in content.items.enumerated() {
                guard let row = try Row.fetchOne(
                    db,
                    sql: """
                        SELECT schedule_occurrences.activity_id, schedule_occurrences.scheduled_date,
                               schedule_occurrences.start_time, schedule_occurrences.end_time,
                               schedule_occurrences.priority, activities.title, activities.details
                        FROM schedule_occurrences
                        JOIN activities ON activities.id = schedule_occurrences.activity_id
                        WHERE schedule_occurrences.id = ?
                        """,
                    arguments: [uuid(item.occurrenceID)]
                ) else { throw OperationalCommandValidationError.missingReference }
                guard (row["scheduled_date"] as String) == date else {
                    throw OperationalCommandValidationError.occurrenceDateMismatch
                }
                let parent = try snapshotParent(versionID: item.parentVersionID, in: db)
                items.append(.init(
                    occurrenceID: item.occurrenceID,
                    activityID: try decodedUUID(row["activity_id"]),
                    title: row["title"],
                    details: row["details"],
                    date: row["scheduled_date"],
                    startTime: row["start_time"],
                    endTime: row["end_time"],
                    priority: row["priority"],
                    order: index + 1,
                    parent: parent
                ))
            }
        }
        return OperationalCommandSnapshot(
            kind: kind,
            number: number,
            versionNumber: versionNumber,
            title: content.title,
            details: content.details,
            date: date ?? content.effectiveDate,
            classification: content.classification,
            priority: content.priority,
            targets: targets,
            items: items
        )
    }

    private func snapshotParent(versionID: UUID?, in db: Database) throws -> OperationalCommandSnapshotParent? {
        guard let versionID else { return nil }
        guard let row = try Row.fetchOne(
            db,
            sql: """
                SELECT operational_commands.kind, operational_commands.sequence_number,
                       operational_command_versions.version_number, operational_command_versions.state,
                       operational_command_versions.snapshot_json
                FROM operational_command_versions
                JOIN operational_commands ON operational_commands.id = operational_command_versions.command_id
                WHERE operational_command_versions.id = ?
                """,
            arguments: [uuid(versionID)]
        ), (row["kind"] as String) == OperationalCommandKind.parent.rawValue,
           (row["state"] as String) == OperationalCommandVersionState.published.rawValue,
           let snapshotJSON: String = row["snapshot_json"] else {
            throw OperationalCommandValidationError.parentVersionNotPublished
        }
        let snapshot = try decode(OperationalCommandSnapshot.self, from: snapshotJSON)
        return OperationalCommandSnapshotParent(
            versionID: versionID,
            number: "PI-\(String(format: "%06d", row["sequence_number"] as Int))",
            versionNumber: row["version_number"],
            title: snapshot.title,
            details: snapshot.details,
            date: snapshot.date,
            classification: snapshot.classification,
            priority: snapshot.priority
        )
    }

    private func commandNumber(kind: OperationalCommandKind, commandID: String, in db: Database) throws -> String {
        guard let row = try Row.fetchOne(
            db,
            sql: "SELECT sequence_number, command_date FROM operational_commands WHERE id = ?",
            arguments: [commandID]
        ) else { throw OperationalCommandValidationError.missingReference }
        switch kind {
        case .parent: return "PI-\(String(format: "%06d", row["sequence_number"] as Int))"
        case .daily: return "PH-\((row["command_date"] as String).replacingOccurrences(of: "-", with: ""))"
        }
    }

    private func commandVersionRow(id: UUID, in db: Database) throws -> Row? {
        try Row.fetchOne(
            db,
            sql: """
                SELECT operational_command_versions.id, operational_command_versions.command_id,
                       operational_command_versions.version_number, operational_command_versions.state,
                       operational_command_versions.content_json, operational_command_versions.snapshot_json,
                       operational_command_versions.created_at, operational_command_versions.published_at,
                       operational_command_versions.replaced_by_version_id,
                       operational_commands.kind, operational_commands.command_date
                FROM operational_command_versions
                JOIN operational_commands ON operational_commands.id = operational_command_versions.command_id
                WHERE operational_command_versions.id = ?
                """,
            arguments: [uuid(id)]
        )
    }

    private func readCommand(row: Row, in db: Database) throws -> OperationalCommand {
        let id = try decodedUUID(row["id"])
        let currentID = try String.fetchOne(
            db,
            sql: "SELECT id FROM operational_command_versions WHERE command_id = ? AND state = 'published'",
            arguments: [uuid(id)]
        ).map { try decodedUUID($0) }
        let latest = try Int.fetchOne(
            db,
            sql: "SELECT COALESCE(MAX(version_number), 0) FROM operational_command_versions WHERE command_id = ?",
            arguments: [uuid(id)]
        ) ?? 0
        let kind = OperationalCommandKind(rawValue: row["kind"] as String)!
        let number: String
        if kind == .parent {
            number = "PI-\(String(format: "%06d", row["sequence_number"] as Int))"
        } else {
            number = "PH-\((row["command_date"] as String).replacingOccurrences(of: "-", with: ""))"
        }
        return OperationalCommand(
            id: id,
            kind: kind,
            number: number,
            date: row["command_date"],
            createdAt: Date(timeIntervalSince1970: row["created_at"]),
            latestVersionNumber: latest,
            currentPublishedVersionID: currentID
        )
    }

    private func readVersion(id: UUID, in db: Database) throws -> OperationalCommandVersion {
        guard let row = try commandVersionRow(id: id, in: db) else {
            throw OperationalCommandValidationError.missingReference
        }
        guard let state = OperationalCommandVersionState(rawValue: row["state"] as String),
              let kind = OperationalCommandKind(rawValue: row["kind"] as String) else {
            throw OperationalCommandValidationError.corruptedStoredContent
        }
        let commandID = try decodedUUID(row["command_id"])
        let commandRow = try Row.fetchOne(
            db,
            sql: "SELECT sequence_number, command_date FROM operational_commands WHERE id = ?",
            arguments: [uuid(commandID)]
        )!
        let number: String
        if kind == .parent {
            number = "PI-\(String(format: "%06d", commandRow["sequence_number"] as Int))"
        } else {
            number = "PH-\((commandRow["command_date"] as String).replacingOccurrences(of: "-", with: ""))"
        }
        let content = try decode(OperationalCommandDraftContent.self, from: row["content_json"])
        let snapshot: OperationalCommandSnapshot?
        if let snapshotJSON: String = row["snapshot_json"] {
            snapshot = try decode(OperationalCommandSnapshot.self, from: snapshotJSON)
        } else {
            snapshot = nil
        }
        let replacedBy: UUID?
        if let raw: String = row["replaced_by_version_id"] {
            replacedBy = try decodedUUID(raw)
        } else {
            replacedBy = nil
        }
        return OperationalCommandVersion(
            id: id,
            commandID: commandID,
            number: number,
            versionNumber: row["version_number"],
            state: state,
            createdAt: Date(timeIntervalSince1970: row["created_at"]),
            publishedAt: (row["published_at"] as Double?).map(Date.init(timeIntervalSince1970:)),
            content: content,
            snapshot: snapshot,
            replacedByVersionID: replacedBy
        )
    }

    private func encode<T: Encodable>(_ value: T) throws -> String {
        guard let value = String(data: try JSONEncoder().encode(value), encoding: .utf8) else {
            throw OperationalCommandValidationError.corruptedStoredContent
        }
        return value
    }

    private func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
        do { return try JSONDecoder().decode(type, from: Data(json.utf8)) }
        catch { throw OperationalCommandValidationError.corruptedStoredContent }
    }

    private func uuid(_ value: UUID) -> String { value.uuidString.lowercased() }

    private func decodedUUID(_ value: String) throws -> UUID {
        guard let id = UUID(uuidString: value) else {
            throw OperationalCommandValidationError.corruptedStoredContent
        }
        return id
    }
}
