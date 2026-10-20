import Foundation
import GRDB

public struct PlanningImportRepository {
    private let databaseQueue: DatabaseQueue

    public init(databaseQueue: DatabaseQueue) {
        self.databaseQueue = databaseQueue
    }

    public func preview(_ data: Data) throws -> PlanningImportSummary {
        let prepared = try PreparedPlanningImport(data: data)
        return try databaseQueue.read { db in try analyze(prepared, in: db).summary }
    }

    @discardableResult
    public func importJSON(_ data: Data) throws -> PlanningImportSummary {
        let prepared = try PreparedPlanningImport(data: data)
        return try databaseQueue.write { db in
            let plan = try analyze(prepared, in: db)
            guard plan.summary.canImport else {
                throw PlanningImportError.importHasConflicts(plan.summary.issues)
            }
            for value in plan.plans {
                try db.execute(sql: "INSERT INTO plans (id, title, start_date, end_date) VALUES (?, ?, ?, ?)", arguments: [id(value.id), value.title, value.startDate, value.endDate])
            }
            for value in plan.activities {
                try db.execute(sql: "INSERT INTO activities (id, title, details) VALUES (?, ?, ?)", arguments: [id(value.id), value.title, value.details])
            }
            for value in plan.planActivities {
                try db.execute(sql: "INSERT INTO plan_activities (id, plan_id, activity_id) VALUES (?, ?, ?)", arguments: [id(UUID()), id(value.planID), id(value.relatedID)])
            }
            for value in plan.objectives {
                try db.execute(sql: "INSERT INTO objectives (id, title, details) VALUES (?, ?, ?)", arguments: [id(value.id), value.title, value.details])
            }
            for value in plan.planObjectives {
                try db.execute(sql: "INSERT INTO plan_objectives (id, plan_id, objective_id) VALUES (?, ?, ?)", arguments: [id(UUID()), id(value.planID), id(value.relatedID)])
            }
            for value in plan.occurrences {
                try db.execute(
                    sql: "INSERT INTO schedule_occurrences (id, activity_id, scheduled_date, start_time, end_time, priority) VALUES (?, ?, ?, ?, ?, ?)",
                    arguments: [id(value.id), id(value.activityID), value.scheduledDate, value.startTime, value.endTime, value.priority]
                )
            }
            return plan.summary
        }
    }

    private func analyze(_ prepared: PreparedPlanningImport, in db: Database) throws -> ImportPlan {
        var issues: [String] = []
        var alreadyPresent = 0
        var plansToInsert: [Plan] = []
        for value in prepared.plans {
            if let row = try Row.fetchOne(db, sql: "SELECT title, start_date, end_date FROM plans WHERE id = ?", arguments: [id(value.id)]) {
                if row["title"] == value.title && row["start_date"] == value.startDate && row["end_date"] == value.endDate {
                    alreadyPresent += 1
                } else { issues.append("Plan \(value.id) already exists with different contents") }
            } else { plansToInsert.append(value) }
        }

        var activitiesToInsert: [Activity] = []
        for value in prepared.activities {
            if let row = try Row.fetchOne(db, sql: "SELECT title, details FROM activities WHERE id = ?", arguments: [id(value.id)]) {
                if row["title"] == value.title && row["details"] == value.details { alreadyPresent += 1 }
                else { issues.append("Activity \(value.id) already exists with different contents") }
            } else { activitiesToInsert.append(value) }
        }

        var objectivesToInsert: [Objective] = []
        for value in prepared.objectives {
            if let row = try Row.fetchOne(db, sql: "SELECT title, details FROM objectives WHERE id = ?", arguments: [id(value.id)]) {
                if row["title"] == value.title && row["details"] == value.details { alreadyPresent += 1 }
                else { issues.append("Objective \(value.id) already exists with different contents") }
            } else { objectivesToInsert.append(value) }
        }

        let availablePlanIDs = try existingIDs("plans", in: db).union(prepared.plans.map(\.id))
        let availableActivityIDs = try existingIDs("activities", in: db).union(prepared.activities.map(\.id))
        let availableObjectiveIDs = try existingIDs("objectives", in: db).union(prepared.objectives.map(\.id))

        var planActivitiesToInsert: [ImportLink] = []
        for link in prepared.planActivities {
            guard availablePlanIDs.contains(link.planID), availableActivityIDs.contains(link.relatedID) else {
                issues.append("Plan–Activity relationship references a missing record")
                continue
            }
            let exists = try Bool.fetchOne(db, sql: "SELECT EXISTS(SELECT 1 FROM plan_activities WHERE plan_id = ? AND activity_id = ?)", arguments: [id(link.planID), id(link.relatedID)]) ?? false
            if exists { alreadyPresent += 1 } else { planActivitiesToInsert.append(link) }
        }

        var planObjectivesToInsert: [ImportLink] = []
        for link in prepared.planObjectives {
            guard availablePlanIDs.contains(link.planID), availableObjectiveIDs.contains(link.relatedID) else {
                issues.append("Plan–Objective relationship references a missing record")
                continue
            }
            let exists = try Bool.fetchOne(db, sql: "SELECT EXISTS(SELECT 1 FROM plan_objectives WHERE plan_id = ? AND objective_id = ?)", arguments: [id(link.planID), id(link.relatedID)]) ?? false
            if exists { alreadyPresent += 1 } else { planObjectivesToInsert.append(link) }
        }

        var occurrencesToInsert: [ScheduleOccurrence] = []
        for value in prepared.occurrences {
            guard availableActivityIDs.contains(value.activityID) else {
                issues.append("Occurrence \(value.id) references a missing Activity")
                continue
            }
            if let row = try Row.fetchOne(
                db,
                sql: "SELECT activity_id, scheduled_date, start_time, end_time, priority FROM schedule_occurrences WHERE id = ?",
                arguments: [id(value.id)]
            ) {
                let matches = row["activity_id"] == id(value.activityID)
                    && row["scheduled_date"] == value.scheduledDate
                    && row["start_time"] as String? == value.startTime
                    && row["end_time"] as String? == value.endTime
                    && row["priority"] as Int? == value.priority
                if matches { alreadyPresent += 1 }
                else { issues.append("Occurrence \(value.id) already exists with different contents") }
            } else { occurrencesToInsert.append(value) }
        }

        let summary = PlanningImportSummary(
            plansToAdd: plansToInsert.count,
            activitiesToAdd: activitiesToInsert.count,
            linksToAdd: planActivitiesToInsert.count,
            objectivesToAdd: objectivesToInsert.count,
            objectiveLinksToAdd: planObjectivesToInsert.count,
            occurrencesToAdd: occurrencesToInsert.count,
            alreadyPresent: alreadyPresent,
            issues: issues,
            planTitles: plansToInsert.map(\.title),
            activityTitles: activitiesToInsert.map(\.title),
            objectiveTitles: objectivesToInsert.map(\.title),
            occurrenceDates: occurrencesToInsert.map(\.scheduledDate)
        )
        return ImportPlan(
            plans: plansToInsert,
            activities: activitiesToInsert,
            planActivities: planActivitiesToInsert,
            objectives: objectivesToInsert,
            planObjectives: planObjectivesToInsert,
            occurrences: occurrencesToInsert,
            summary: summary
        )
    }

    private func existingIDs(_ table: String, in db: Database) throws -> Set<UUID> {
        let values = try String.fetchAll(db, sql: "SELECT id FROM \(table)")
        return Set(values.compactMap(UUID.init(uuidString:)))
    }

    private func id(_ value: UUID) -> String { value.uuidString.lowercased() }
}

private struct PreparedPlanningImport {
    let plans: [Plan]
    let activities: [Activity]
    let planActivities: [ImportLink]
    let objectives: [Objective]
    let planObjectives: [ImportLink]
    let occurrences: [ScheduleOccurrence]

    init(data: Data) throws {
        let document = try JSONDecoder().decode(PlanningImportDocument.self, from: data)
        guard document.format == "minority.planning" else { throw PlanningImportError.unsupportedFormat }
        guard document.version == 1 else { throw PlanningImportError.unsupportedVersion(document.version) }

        plans = try Self.unique(document.plans.map { try Plan(id: Self.identifier($0.id), title: $0.title, startDate: $0.startDate, endDate: $0.endDate) })
        activities = try Self.unique(document.activities.map { try Activity(id: Self.identifier($0.id), title: $0.title, details: $0.details) })
        objectives = try Self.unique(document.objectives.map { try Objective(id: Self.identifier($0.id), title: $0.title, details: $0.details) })
        planActivities = try Self.unique(document.planActivities.map { try ImportLink(planID: Self.identifier($0.planID), relatedID: Self.identifier($0.activityID)) })
        planObjectives = try Self.unique(document.planObjectives.map { try ImportLink(planID: Self.identifier($0.planID), relatedID: Self.identifier($0.objectiveID)) })
        occurrences = try Self.unique(document.scheduleOccurrences.map {
            try ScheduleOccurrence(
                id: Self.identifier($0.id), activityID: Self.identifier($0.activityID),
                scheduledDate: $0.scheduledDate, startTime: $0.startTime, endTime: $0.endTime, priority: $0.priority
            )
        })
    }

    private static func identifier(_ value: String) throws -> UUID {
        guard let id = UUID(uuidString: value) else { throw PlanningImportError.invalidIdentifier(value) }
        return id
    }

    private static func unique<Value: Identifiable>(_ values: [Value]) throws -> [Value] where Value.ID: Hashable {
        var seen = Set<Value.ID>()
        for value in values where !seen.insert(value.id).inserted {
            throw PlanningImportError.duplicateIdentifier(String(describing: value.id))
        }
        return values
    }

    private static func unique(_ values: [ImportLink]) throws -> [ImportLink] {
        var seen = Set<ImportLink>()
        for value in values where !seen.insert(value).inserted {
            throw PlanningImportError.duplicateRelationship("\(value.planID) → \(value.relatedID)")
        }
        return values
    }
}

private struct ImportLink: Hashable, Identifiable {
    var id: String { "\(planID.uuidString)|\(relatedID.uuidString)" }
    let planID: UUID
    let relatedID: UUID
    init(planID: UUID, relatedID: UUID) { self.planID = planID; self.relatedID = relatedID }
}

private struct ImportPlan {
    let plans: [Plan]
    let activities: [Activity]
    let planActivities: [ImportLink]
    let objectives: [Objective]
    let planObjectives: [ImportLink]
    let occurrences: [ScheduleOccurrence]
    let summary: PlanningImportSummary
}
