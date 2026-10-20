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
    public func create(_ activity: Activity, linkedToPlanID planID: UUID) throws -> PlanActivity {
        let relationship = PlanActivity(planID: planID, activityID: activity.id)
        try databaseQueue.write { db in
            try db.execute(
                sql: "INSERT INTO activities (id, title, details) VALUES (?, ?, ?)",
                arguments: [activity.id.uuidString.lowercased(), activity.title, activity.details]
            )
            try db.execute(
                sql: "INSERT INTO plan_activities (id, plan_id, activity_id) VALUES (?, ?, ?)",
                arguments: [
                    relationship.id.uuidString.lowercased(),
                    planID.uuidString.lowercased(),
                    activity.id.uuidString.lowercased()
                ]
            )
        }
        return relationship
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

    public func create(_ objective: Objective) throws {
        try databaseQueue.write { db in
            try db.execute(
                sql: "INSERT INTO objectives (id, title, details) VALUES (?, ?, ?)",
                arguments: [objective.id.uuidString.lowercased(), objective.title, objective.details]
            )
        }
    }

    @discardableResult
    public func create(_ objective: Objective, linkedToPlanID planID: UUID) throws -> PlanObjective {
        let relationship = PlanObjective(planID: planID, objectiveID: objective.id)
        try databaseQueue.write { db in
            try db.execute(
                sql: "INSERT INTO objectives (id, title, details) VALUES (?, ?, ?)",
                arguments: [objective.id.uuidString.lowercased(), objective.title, objective.details]
            )
            try insert(relationship, into: db)
        }
        return relationship
    }

    @discardableResult
    public func link(objectiveID: UUID, toPlanID planID: UUID) throws -> PlanObjective {
        let relationship = PlanObjective(planID: planID, objectiveID: objectiveID)
        try databaseQueue.write { db in
            try insert(relationship, into: db)
        }
        return relationship
    }

    public func unlink(objectiveID: UUID, fromPlanID planID: UUID) throws {
        try databaseQueue.write { db in
            try db.execute(
                sql: "DELETE FROM plan_objectives WHERE objective_id = ? AND plan_id = ?",
                arguments: [objectiveID.uuidString.lowercased(), planID.uuidString.lowercased()]
            )
        }
    }

    @discardableResult
    public func update(_ objective: Objective) throws -> Bool {
        try databaseQueue.write { db in
            try db.execute(
                sql: "UPDATE objectives SET title = ?, details = ? WHERE id = ?",
                arguments: [objective.title, objective.details, objective.id.uuidString.lowercased()]
            )
            return db.changesCount > 0
        }
    }

    @discardableResult
    public func deleteObjective(id: UUID) throws -> Bool {
        try databaseQueue.write { db in
            try db.execute(sql: "DELETE FROM objectives WHERE id = ?", arguments: [id.uuidString.lowercased()])
            return db.changesCount > 0
        }
    }

    public func objectivePlanCount(id: UUID) throws -> Int {
        try databaseQueue.read { db in
            try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM plan_objectives WHERE objective_id = ?",
                arguments: [id.uuidString.lowercased()]
            ) ?? 0
        }
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

    public func recordExecution(_ record: ExecutionRecord) throws {
        try databaseQueue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO execution_records (id, occurrence_id, recorded_at)
                    VALUES (?, ?, ?)
                    """,
                arguments: [
                    record.id.uuidString.lowercased(),
                    record.occurrenceID.uuidString.lowercased(),
                    record.recordedAt.timeIntervalSince1970
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

    public func plans() throws -> [Plan] {
        try databaseQueue.read { db in
            try Row.fetchAll(
                db,
                sql: "SELECT id, title, start_date, end_date FROM plans ORDER BY start_date, title, id"
            ).map { row in
                try Plan(
                    id: decodedUUID(row["id"]),
                    title: row["title"],
                    startDate: row["start_date"],
                    endDate: row["end_date"]
                )
            }
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

    public func activities(forPlanID planID: UUID) throws -> [Activity] {
        try databaseQueue.read { db in
            try Row.fetchAll(
                db,
                sql: """
                    SELECT activities.id, activities.title, activities.details
                    FROM activities
                    JOIN plan_activities ON plan_activities.activity_id = activities.id
                    WHERE plan_activities.plan_id = ?
                    ORDER BY activities.title, activities.id
                    """,
                arguments: [planID.uuidString.lowercased()]
            ).map { row in
                try Activity(
                    id: decodedUUID(row["id"]),
                    title: row["title"],
                    details: row["details"]
                )
            }
        }
    }

    public func activitiesNotLinked(toPlanID planID: UUID) throws -> [Activity] {
        try databaseQueue.read { db in
            try Row.fetchAll(
                db,
                sql: """
                    SELECT activities.id, activities.title, activities.details
                    FROM activities
                    WHERE NOT EXISTS (
                        SELECT 1
                        FROM plan_activities
                        WHERE plan_activities.activity_id = activities.id
                            AND plan_activities.plan_id = ?
                    )
                    ORDER BY activities.title, activities.id
                    """,
                arguments: [planID.uuidString.lowercased()]
            ).map { row in
                try Activity(
                    id: decodedUUID(row["id"]),
                    title: row["title"],
                    details: row["details"]
                )
            }
        }
    }

    public func objective(id: UUID) throws -> Objective? {
        try databaseQueue.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT id, title, details FROM objectives WHERE id = ?",
                arguments: [id.uuidString.lowercased()]
            ) else { return nil }
            return try Objective(
                id: decodedUUID(row["id"]),
                title: row["title"],
                details: row["details"]
            )
        }
    }

    public func objectives() throws -> [Objective] {
        try databaseQueue.read { db in
            try Row.fetchAll(db, sql: "SELECT id, title, details FROM objectives ORDER BY title, id")
                .map { row in
                    try Objective(
                        id: decodedUUID(row["id"]),
                        title: row["title"],
                        details: row["details"]
                    )
                }
        }
    }

    public func planObjectives(forPlanID planID: UUID) throws -> [PlanObjective] {
        try databaseQueue.read { db in
            try Row.fetchAll(
                db,
                sql: "SELECT id, plan_id, objective_id FROM plan_objectives WHERE plan_id = ? ORDER BY id",
                arguments: [planID.uuidString.lowercased()]
            ).map { row in
                PlanObjective(
                    id: try decodedUUID(row["id"]),
                    planID: try decodedUUID(row["plan_id"]),
                    objectiveID: try decodedUUID(row["objective_id"])
                )
            }
        }
    }

    public func objectives(forPlanID planID: UUID) throws -> [Objective] {
        try databaseQueue.read { db in
            try Row.fetchAll(
                db,
                sql: """
                    SELECT objectives.id, objectives.title, objectives.details
                    FROM objectives
                    JOIN plan_objectives ON plan_objectives.objective_id = objectives.id
                    WHERE plan_objectives.plan_id = ?
                    ORDER BY objectives.title, objectives.id
                    """,
                arguments: [planID.uuidString.lowercased()]
            ).map { row in
                try Objective(
                    id: decodedUUID(row["id"]),
                    title: row["title"],
                    details: row["details"]
                )
            }
        }
    }

    public func objectivesNotLinked(toPlanID planID: UUID) throws -> [Objective] {
        try databaseQueue.read { db in
            try Row.fetchAll(
                db,
                sql: """
                    SELECT objectives.id, objectives.title, objectives.details
                    FROM objectives
                    WHERE NOT EXISTS (
                        SELECT 1
                        FROM plan_objectives
                        WHERE plan_objectives.objective_id = objectives.id
                            AND plan_objectives.plan_id = ?
                    )
                    ORDER BY objectives.title, objectives.id
                    """,
                arguments: [planID.uuidString.lowercased()]
            ).map { row in
                try Objective(
                    id: decodedUUID(row["id"]),
                    title: row["title"],
                    details: row["details"]
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

    public func executionRecords(forActivityID activityID: UUID) throws -> [ExecutionRecord] {
        try databaseQueue.read { db in
            try Row.fetchAll(
                db,
                sql: """
                    SELECT execution_records.id, execution_records.occurrence_id, execution_records.recorded_at
                    FROM execution_records
                    JOIN schedule_occurrences ON schedule_occurrences.id = execution_records.occurrence_id
                    WHERE schedule_occurrences.activity_id = ?
                    ORDER BY execution_records.recorded_at, execution_records.id
                    """,
                arguments: [activityID.uuidString.lowercased()]
            ).map { row in
                try ExecutionRecord(
                    id: decodedUUID(row["id"]),
                    occurrenceID: decodedUUID(row["occurrence_id"]),
                    recordedAt: Date(timeIntervalSince1970: row["recorded_at"])
                )
            }
        }
    }

    public func executionRecord(forOccurrenceID occurrenceID: UUID) throws -> ExecutionRecord? {
        try databaseQueue.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: """
                    SELECT id, occurrence_id, recorded_at
                    FROM execution_records
                    WHERE occurrence_id = ?
                    """,
                arguments: [occurrenceID.uuidString.lowercased()]
            ) else { return nil }
            return try ExecutionRecord(
                id: decodedUUID(row["id"]),
                occurrenceID: decodedUUID(row["occurrence_id"]),
                recordedAt: Date(timeIntervalSince1970: row["recorded_at"])
            )
        }
    }
}

private func decodedUUID(_ value: String) throws -> UUID {
    guard let id = UUID(uuidString: value) else {
        throw PlanningPersistenceError.invalidStoredIdentifier(value)
    }
    return id
}

private func insert(_ relationship: PlanObjective, into db: Database) throws {
    try db.execute(
        sql: "INSERT INTO plan_objectives (id, plan_id, objective_id) VALUES (?, ?, ?)",
        arguments: [
            relationship.id.uuidString.lowercased(),
            relationship.planID.uuidString.lowercased(),
            relationship.objectiveID.uuidString.lowercased()
        ]
    )
}

private enum PlanningPersistenceError: Error {
    case invalidStoredIdentifier(String)
}
