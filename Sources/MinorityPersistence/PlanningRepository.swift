import Foundation
import GRDB

public struct PlanningRepository {
    private let databaseQueue: DatabaseQueue

    public init(databaseQueue: DatabaseQueue) {
        self.databaseQueue = databaseQueue
    }

    public func create(_ plan: Plan) throws {
        try databaseQueue.write { db in
            try db.execute(
                sql: "INSERT INTO plans (id, title, start_date, end_date) VALUES (?, ?, ?, ?)",
                arguments: [plan.id.uuidString.lowercased(), plan.title, plan.startDate, plan.endDate]
            )
        }
    }

    public func create(_ activity: Activity) throws {
        try databaseQueue.write { db in
            try db.execute(
                sql: "INSERT INTO activities (id, title, details) VALUES (?, ?, ?)",
                arguments: [activity.id.uuidString.lowercased(), activity.title, activity.details]
            )
        }
    }

    @discardableResult
    public func link(activityID: UUID, toPlanID planID: UUID) throws -> PlanActivity {
        let relationship = PlanActivity(planID: planID, activityID: activityID)
        try databaseQueue.write { db in
            try db.execute(
                sql: "INSERT INTO plan_activities (id, plan_id, activity_id) VALUES (?, ?, ?)",
                arguments: [
                    relationship.id.uuidString.lowercased(),
                    planID.uuidString.lowercased(),
                    activityID.uuidString.lowercased()
                ]
            )
        }
        return relationship
    }

    public func schedule(_ occurrence: ScheduleOccurrence) throws {
        try databaseQueue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO schedule_occurrences
                        (id, activity_id, scheduled_date, start_time, end_time, priority)
                    VALUES (?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    occurrence.id.uuidString.lowercased(),
                    occurrence.activityID.uuidString.lowercased(),
                    occurrence.scheduledDate,
                    occurrence.startTime,
                    occurrence.endTime,
                    occurrence.priority
                ]
            )
        }
    }

    public func plan(id: UUID) throws -> Plan? {
        try databaseQueue.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT id, title, start_date, end_date FROM plans WHERE id = ?",
                arguments: [id.uuidString.lowercased()]
            ) else { return nil }
            return try Plan(
                id: decodedUUID(row["id"]),
                title: row["title"],
                startDate: row["start_date"],
                endDate: row["end_date"]
            )
        }
    }

    public func activity(id: UUID) throws -> Activity? {
        try databaseQueue.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT id, title, details FROM activities WHERE id = ?",
                arguments: [id.uuidString.lowercased()]
            ) else { return nil }
            return try Activity(
                id: decodedUUID(row["id"]),
                title: row["title"],
                details: row["details"]
            )
        }
    }

    public func planActivities(forPlanID planID: UUID) throws -> [PlanActivity] {
        try databaseQueue.read { db in
            try Row.fetchAll(
                db,
                sql: "SELECT id, plan_id, activity_id FROM plan_activities WHERE plan_id = ? ORDER BY id",
                arguments: [planID.uuidString.lowercased()]
            ).map { row in
                try PlanActivity(
                    id: decodedUUID(row["id"]),
                    planID: decodedUUID(row["plan_id"]),
                    activityID: decodedUUID(row["activity_id"])
                )
            }
        }
    }

    public func scheduleOccurrences(forActivityID activityID: UUID) throws -> [ScheduleOccurrence] {
        try databaseQueue.read { db in
            try Row.fetchAll(
                db,
                sql: """
                    SELECT id, activity_id, scheduled_date, start_time, end_time, priority
                    FROM schedule_occurrences
                    WHERE activity_id = ?
                    ORDER BY scheduled_date, start_time, id
                    """,
                arguments: [activityID.uuidString.lowercased()]
            ).map { row in
                try ScheduleOccurrence(
                    id: decodedUUID(row["id"]),
                    activityID: decodedUUID(row["activity_id"]),
                    scheduledDate: row["scheduled_date"],
                    startTime: row["start_time"],
                    endTime: row["end_time"],
                    priority: row["priority"]
                )
            }
        }
    }
}

private func decodedUUID(_ value: String) throws -> UUID {
    guard let id = UUID(uuidString: value) else {
        throw PlanningPersistenceError.invalidStoredIdentifier(value)
    }
    return id
}

private enum PlanningPersistenceError: Error {
    case invalidStoredIdentifier(String)
}
