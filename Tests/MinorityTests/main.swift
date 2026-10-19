import Foundation
import GRDB
import MinorityPersistence

@main
enum DatabaseManagerChecks {
    static func main() throws {
        try checkDatabaseInitializationReadWriteAndMigrationIdempotency()
        try checkInitializationFailurePreservesExistingData()
        try checkCorePlanningPersistence()
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
        try require(
            appliedMigrations == ["foundation", "planning_v1"],
            "Foundation and planning migrations were not each applied exactly once"
        )
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

    private static func checkCorePlanningPersistence() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let databaseURL = directory.appendingPathComponent("planning.sqlite")
        let manager = try DatabaseManager(databaseURL: databaseURL)
        let repository = PlanningRepository(databaseQueue: manager.databaseQueue)
        try require(try repository.plans().isEmpty, "A new planning database should have an empty plan list")

        let plan = try Plan(
            title: "Autumn Plan",
            startDate: "2026-09-01",
            endDate: "2026-11-30"
        )
        let secondPlan = try Plan(
            title: "Year Plan",
            startDate: "2026-01-01",
            endDate: "2026-12-31"
        )
        let activity = try Activity(title: "Read", details: "Read a chapter")
        let linkedActivity = try Activity(title: "Walk", details: "Take a short walk")

        try repository.create(plan)
        try repository.create(secondPlan)
        try repository.create(activity)
        try repository.create(linkedActivity, linkedToPlanID: plan.id)
        try require(try repository.plan(id: plan.id) == plan, "Plan creation was not persisted")
        try require(try repository.activity(id: activity.id) == activity, "Activity creation was not persisted")
        try require(try repository.plans() == [secondPlan, plan], "Plans were not listed in a stable date order")
        try require(
            try repository.activitiesNotLinked(toPlanID: plan.id).map(\.id) == [activity.id],
            "An activity already linked to a plan was not excluded from available activities"
        )
        try require(
            try repository.activitiesNotLinked(toPlanID: secondPlan.id).map(\.id) == [activity.id, linkedActivity.id],
            "Activities linked elsewhere were not available to another plan"
        )
        try require(
            try repository.scheduleOccurrences(forActivityID: activity.id).isEmpty,
            "An activity received a schedule without an explicit scheduling action"
        )

        let firstLink = try repository.link(activityID: activity.id, toPlanID: plan.id)
        let secondLink = try repository.link(activityID: activity.id, toPlanID: secondPlan.id)
        try require(firstLink.activityID == activity.id, "Plan-activity link points to the wrong activity")
        try require(secondLink.activityID == activity.id, "Activity could not be linked to a second plan")
        try require(
            try repository.activitiesNotLinked(toPlanID: secondPlan.id).map(\.id) == [linkedActivity.id],
            "A newly linked activity remained available for a duplicate link"
        )
        try require(
            Set(try repository.planActivities(forPlanID: plan.id).map(\.activityID)) == Set([activity.id, linkedActivity.id]),
            "Plan-activity relationship was not persisted"
        )
        try require(
            Set(try repository.activities(forPlanID: plan.id).map(\.id)) == Set([activity.id, linkedActivity.id]),
            "Activities linked through the atomic creation operation were not listed for the plan"
        )

        let unlinkedCandidate = try Activity(title: "Must roll back")
        do {
            try repository.create(unlinkedCandidate, linkedToPlanID: UUID())
            throw CheckFailure(description: "Activity creation with a missing plan unexpectedly succeeded")
        } catch is CheckFailure {
            throw CheckFailure(description: "Activity creation with a missing plan unexpectedly succeeded")
        } catch is DatabaseError {
            try require(
                try repository.activity(id: unlinkedCandidate.id) == nil,
                "Failed activity-to-plan linking left an orphan activity"
            )
        }

        do {
            _ = try repository.link(activityID: activity.id, toPlanID: plan.id)
            throw CheckFailure(description: "Duplicate plan-activity relationship was accepted")
        } catch is DatabaseError {
            // Expected: the unique constraint rejects duplicate links.
        }

        let firstOccurrence = try ScheduleOccurrence(
            activityID: activity.id,
            scheduledDate: "2026-10-20",
            startTime: "09:00",
            endTime: "10:00",
            priority: 2
        )
        let secondOccurrence = try ScheduleOccurrence(
            activityID: activity.id,
            scheduledDate: "2026-10-21"
        )
        try repository.schedule(firstOccurrence)
        try repository.schedule(secondOccurrence)
        let occurrences = try repository.scheduleOccurrences(forActivityID: activity.id)
        try require(occurrences.count == 2, "Multiple occurrences for one activity were not persisted")
        try require(Set(occurrences.map(\.id)) == Set([firstOccurrence.id, secondOccurrence.id]), "Occurrence IDs were not stable")
        try require(occurrences.first == firstOccurrence, "Scheduled date, time, or priority was not persisted")

        var rejectedInvalidDate = false
        do {
            _ = try Plan(title: "Invalid", startDate: "2026-02-30", endDate: "2026-03-01")
        } catch {
            rejectedInvalidDate = true
        }
        try require(rejectedInvalidDate, "Invalid calendar date was accepted")

        var rejectedInvalidDateByDatabase = false
        do {
            try manager.databaseQueue.write { db in
                try db.execute(
                    sql: "INSERT INTO plans (id, title, start_date, end_date) VALUES (?, ?, ?, ?)",
                    arguments: [UUID().uuidString.lowercased(), "Invalid", "2026-02-30", "2026-03-01"]
                )
            }
        } catch is DatabaseError {
            rejectedInvalidDateByDatabase = true
        }
        try require(rejectedInvalidDateByDatabase, "Database accepted an invalid calendar date")

        var rejectedInvalidPlanRange = false
        do {
            _ = try Plan(title: "Invalid", startDate: "2026-03-02", endDate: "2026-03-01")
        } catch {
            rejectedInvalidPlanRange = true
        }
        try require(rejectedInvalidPlanRange, "Reversed plan date range was accepted")

        var rejectedIncompleteTime = false
        do {
            _ = try ScheduleOccurrence(activityID: activity.id, scheduledDate: "2026-10-22", startTime: "09:00")
        } catch {
            rejectedIncompleteTime = true
        }
        try require(rejectedIncompleteTime, "Incomplete schedule time range was accepted")

        var rejectedInvalidTime = false
        do {
            _ = try ScheduleOccurrence(
                activityID: activity.id,
                scheduledDate: "2026-10-22",
                startTime: "25:00",
                endTime: "26:00"
            )
        } catch {
            rejectedInvalidTime = true
        }
        try require(rejectedInvalidTime, "Invalid clock time was accepted")

        var rejectedReversedTime = false
        do {
            _ = try ScheduleOccurrence(
                activityID: activity.id,
                scheduledDate: "2026-10-22",
                startTime: "10:00",
                endTime: "09:00"
            )
        } catch {
            rejectedReversedTime = true
        }
        try require(rejectedReversedTime, "Reversed same-day schedule time range was accepted")

        do {
            _ = try repository.link(activityID: UUID(), toPlanID: plan.id)
            throw CheckFailure(description: "Plan-activity link accepted a missing activity")
        } catch is DatabaseError {
            // Expected: the foreign key rejects a missing activity.
        }

        var rejectedMissingScheduleActivity = false
        do {
            try manager.databaseQueue.write { db in
                try db.execute(
                    sql: "INSERT INTO schedule_occurrences (id, activity_id, scheduled_date) VALUES (?, ?, ?)",
                    arguments: [UUID().uuidString.lowercased(), UUID().uuidString.lowercased(), "2026-10-22"]
                )
            }
        } catch is DatabaseError {
            rejectedMissingScheduleActivity = true
        }
        try require(rejectedMissingScheduleActivity, "Database accepted a schedule for a missing activity")

        let reopenedManager = try DatabaseManager(databaseURL: databaseURL)
        let reopenedRepository = PlanningRepository(databaseQueue: reopenedManager.databaseQueue)
        try require(try reopenedRepository.plan(id: plan.id) == plan, "Plan did not survive database reopening")
        try require(
            Set(try reopenedRepository.activities(forPlanID: plan.id).map(\.id)) == Set([activity.id, linkedActivity.id]),
            "Linked activity did not survive database reopening"
        )
        try require(
            try reopenedRepository.scheduleOccurrences(forActivityID: activity.id) == [firstOccurrence, secondOccurrence],
            "Schedule occurrences did not survive database reopening"
        )
        try require(
            try reopenedRepository.plans() == [secondPlan, plan],
            "Plan list did not survive database reopening"
        )
        try require(try reopenedRepository.activity(id: activity.id) == activity, "Activity did not survive database reopening")
        try require(
            try reopenedRepository.scheduleOccurrences(forActivityID: activity.id) == occurrences,
            "Schedule occurrences did not survive database reopening"
        )
        try require(
            try reopenedRepository.planActivities(forPlanID: secondPlan.id).map(\.activityID) == [activity.id],
            "Plan-activity link did not survive database reopening"
        )
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
