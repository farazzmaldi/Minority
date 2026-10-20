import Foundation
import GRDB
import MinorityPersistence

@main
enum DatabaseManagerChecks {
    static func main() throws {
        try checkDatabaseInitializationReadWriteAndMigrationIdempotency()
        try checkInitializationFailurePreservesExistingData()
        try checkCorePlanningPersistence()
        try checkSharedObjectivePersistence()
        try checkOperationalCommandPersistence()
        try checkEvaluationPersistence()
        try checkPlanningJSONImport()
        try checkDocumentPersistence()
        try checkSearchIndex()
        try checkBackupRestoreAndIntegrity()
        try checkUpgradeFromPopulatedPlanningDatabase()
        try checkUpgradeFromPlanningDatabaseBeforeObjectives()
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
            appliedMigrations == ["commands_v1", "documents_v1", "evaluation_v1", "execution_v1", "foundation", "objectives_v1", "planning_v1", "search_v1"],
            "Foundation, planning, execution, objective, command, evaluation, document, and search migrations were not each applied exactly once"
        )
    }

    private static func checkDocumentPersistence() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let manager = try DatabaseManager(databaseURL: directory.appendingPathComponent("documents.sqlite"))
        let source = directory.appendingPathComponent("source.txt")
        let contents = "Local document fixture text"
        try Data(contents.utf8).write(to: source)
        let repository = DocumentRepository(databaseQueue: manager.databaseQueue, applicationSupportDirectory: directory)
        let document = try repository.add(from: source, mediaType: "text/plain", extractedText: contents)
        try require(try Data(contentsOf: repository.fileURL(for: document)) == Data(contents.utf8), "Imported document copy did not preserve source bytes")
        let listedDocuments = try repository.documents()
        try require(
            listedDocuments.count == 1 && listedDocuments[0].id == document.id &&
                listedDocuments[0].filename == document.filename && listedDocuments[0].extractedText == contents,
            "Imported document metadata did not load"
        )

        try repository.moveToTrash(id: document.id)
        try require(try repository.documents().isEmpty, "Trashed document appeared in the active library")
        try require(try repository.documents(includeTrash: true).first?.trashedAt != nil, "Trashed document was not retained for recovery")
        try repository.restore(id: document.id)

        let reopened = try DatabaseManager(databaseURL: directory.appendingPathComponent("documents.sqlite"))
        let reopenedRepository = DocumentRepository(databaseQueue: reopened.databaseQueue, applicationSupportDirectory: directory)
        let reopenedDocuments = try reopenedRepository.documents()
        try require(
            reopenedDocuments.count == 1 && reopenedDocuments[0].id == document.id &&
                reopenedDocuments[0].filename == document.filename && reopenedDocuments[0].extractedText == contents,
            "Document metadata did not survive reopening"
        )
        try require(try Data(contentsOf: reopenedRepository.fileURL(for: document)) == Data(contents.utf8), "Managed document copy did not survive reopening")
    }

    private static func checkSearchIndex() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let manager = try DatabaseManager(databaseURL: directory.appendingPathComponent("search.sqlite"))
        let planning = PlanningRepository(databaseQueue: manager.databaseQueue)
        let plan = try Plan(title: "Daily planning", startDate: "2026-10-20", endDate: "2026-10-22")
        let activity = try Activity(title: "Vocabulary practice", details: "Cross-language learning session")
        try planning.create(plan)
        try planning.create(activity, linkedToPlanID: plan.id)
        let source = directory.appendingPathComponent("search.txt")
        try Data("Distinctive searchable document phrase".utf8).write(to: source)
        let documents = DocumentRepository(databaseQueue: manager.databaseQueue, applicationSupportDirectory: directory)
        let document = try documents.add(from: source, mediaType: "text/plain", extractedText: "Distinctive searchable document phrase")
        let search = SearchRepository(databaseQueue: manager.databaseQueue)

        try search.refreshIndex()
        let exact = try search.textSearch("vocabulary")
        try require(exact.contains(where: { $0.id == "activity:\(activity.id.uuidString.lowercased())" }),
                    "Full-text search did not return the matching activity")
        try require(try search.textSearch("distinctive phrase").contains(where: { $0.id == "document:\(document.id.uuidString.lowercased())" }),
                    "Full-text search did not return extracted document text")

        let indexed = try search.semanticIndexRecords()
        guard let activityRecord = indexed.first(where: { $0.id == "activity:\(activity.id.uuidString.lowercased())" }) else {
            throw CheckFailure(description: "Activity was missing from semantic index records")
        }
        try search.replaceSemanticVectors(for: activityRecord, modelIdentifier: "fixture-model", revision: 1,
                                          vectors: [[1, 0], [0.8, 0.2]])
        try require(try search.semanticSearch(queryVector: [1, 0], modelIdentifier: "fixture-model", revision: 1).first?.id == activityRecord.id,
                    "Semantic vector search did not rank the closest matching record first")

        try manager.databaseQueue.write { db in
            try db.execute(sql: "UPDATE activities SET details = ? WHERE id = ?",
                           arguments: ["Changed source", activity.id.uuidString.lowercased()])
        }
        try search.refreshIndex()
        try require(try search.semanticVectors(modelIdentifier: "fixture-model", revision: 1).isEmpty,
                    "A stale semantic vector remained after its source changed")
        try documents.moveToTrash(id: document.id)
        try search.refreshIndex()
        try require(try search.textSearch("distinctive").isEmpty,
                    "A document in Trash remained in the active search index")
    }

    private static func checkBackupRestoreAndIntegrity() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let support = root.appendingPathComponent("Application Support/Minority", isDirectory: true)
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        let databaseURL = support.appendingPathComponent("minority.sqlite")
        let manager = try DatabaseManager(databaseURL: databaseURL)
        let planning = PlanningRepository(databaseQueue: manager.databaseQueue)
        let originalPlan = try Plan(title: "Before backup", startDate: "2026-10-20", endDate: "2026-10-22")
        try planning.create(originalPlan)
        let source = root.appendingPathComponent("managed.txt")
        let contents = "Backup restore document fixture"
        try Data(contents.utf8).write(to: source)
        let documents = DocumentRepository(databaseQueue: manager.databaseQueue, applicationSupportDirectory: support)
        let document = try documents.add(from: source, mediaType: "text/plain", extractedText: contents)
        let backupManager = DatabaseBackupManager(databaseManager: manager)
        let backupFolder = try backupManager.createBackup(in: root.appendingPathComponent("Backups", isDirectory: true))

        let laterPlan = try Plan(title: "After backup", startDate: "2026-10-23", endDate: "2026-10-25")
        try planning.create(laterPlan)
        try documents.moveToTrash(id: document.id)

        let corruptedFolder = root.appendingPathComponent("Corrupted.minoritybackup", isDirectory: true)
        try FileManager.default.copyItem(at: backupFolder, to: corruptedFolder)
        let corruptedQueue = try DatabaseQueue(path: corruptedFolder.appendingPathComponent("Minority.sqlite").path)
        let documentFilename = try corruptedQueue.read { db in
            try String.fetchOne(db, sql: "SELECT stored_filename FROM local_documents LIMIT 1")
        }
        guard let documentFilename else { throw CheckFailure(description: "Backup fixture has no document entry") }
        let corruptedDocument = corruptedFolder.appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent(documentFilename)
        try Data("tampered bytes".utf8).write(to: corruptedDocument)
        do {
            _ = try backupManager.restore(from: corruptedFolder)
            throw CheckFailure(description: "A backup with a modified document was accepted")
        } catch DatabaseBackupError.documentIntegrityFailure {
            // Validation rejects altered files before touching the active database.
        }
        try require(try planning.plans().contains(laterPlan), "A rejected backup changed the active database")

        let recovery = try backupManager.restore(from: backupFolder)
        let restoredManager = try DatabaseManager(databaseURL: databaseURL)
        let restoredPlanning = PlanningRepository(databaseQueue: restoredManager.databaseQueue)
        let restoredDocuments = DocumentRepository(databaseQueue: restoredManager.databaseQueue, applicationSupportDirectory: support)
        try require(try restoredPlanning.plans() == [originalPlan], "Restore did not replace the active planning data")
        guard let restoredDocument = try restoredDocuments.document(id: document.id) else {
            throw CheckFailure(description: "Restore lost document metadata")
        }
        try require(restoredDocument.trashedAt == nil, "Restore did not preserve the backed-up document state")
        try require(try Data(contentsOf: restoredDocuments.fileURL(for: restoredDocument)) == Data(contents.utf8),
                    "Restore did not return the managed document bytes")
        try require(FileManager.default.fileExists(atPath: recovery.appendingPathComponent("manifest.json").path),
                    "Restore did not create an automatic recovery backup first")
        let migrations = try restoredManager.databaseQueue.read { db in
            try String.fetchAll(db, sql: "SELECT identifier FROM grdb_migrations ORDER BY identifier")
        }
        try require(migrations == DatabaseManager.supportedMigrationIdentifiers.sorted(),
                    "Restore did not upgrade the backup to the current database schema")
    }

    private static func checkEvaluationPersistence() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let manager = try DatabaseManager(databaseURL: directory.appendingPathComponent("evaluation.sqlite"))
        let planning = PlanningRepository(databaseQueue: manager.databaseQueue)
        let evaluations = EvaluationRepository(databaseQueue: manager.databaseQueue)
        let activity = try Activity(title: "Evaluation activity")
        let occurrence = try ScheduleOccurrence(activityID: activity.id, scheduledDate: "2026-10-20")
        try planning.create(activity)
        try planning.schedule(occurrence)
        try planning.recordExecution(try ExecutionRecord(occurrenceID: occurrence.id, recordedAt: .now))
        guard let execution = try planning.executionRecords(forActivityID: activity.id).first else {
            throw CheckFailure(description: "Execution record was not created for evaluation")
        }

        let rubric = try evaluations.createRubric(
            title: "Weekly Review",
            classification: "Personal reflection",
            criteria: ["Evidence", "Next step"]
        )
        let firstResponse = try evaluations.saveEvaluation(
            executionRecordID: execution.id,
            rubric: rubric,
            responses: [rubric.criteria[0].id: "Reviewed the notes"]
        )
        try require(!firstResponse.isComplete, "An unanswered rubric criterion was treated as complete")
        try require(
            try evaluations.latestEvaluation(executionRecordID: execution.id)?.rubric.criteria.count == 2,
            "Incomplete evaluation did not retain its rubric snapshot"
        )

        let revisedRubric = try evaluations.reviseRubric(
            rubricID: rubric.rubricID,
            title: "Weekly Review",
            classification: "Personal reflection v2",
            criteria: ["Evidence", "Next step", "Follow-up"]
        )
        try require(revisedRubric.versionNumber == 2, "Rubric revision did not increment its version")
        let correction = try evaluations.saveEvaluation(
            executionRecordID: execution.id,
            rubric: revisedRubric,
            responses: Dictionary(uniqueKeysWithValues: revisedRubric.criteria.map { ($0.id, "Recorded manually") })
        )
        try require(correction.versionNumber == 2 && correction.isComplete, "Evaluation correction was not saved as a complete new version")
        let latest = try evaluations.latestEvaluation(executionRecordID: execution.id)
        try require(
            latest?.versionNumber == 2
                && latest?.rubric.versionNumber == 2
                && latest?.rubric.criteria.count == 3
                && latest?.isComplete == true,
            "Latest evaluation did not expose its corrected, complete version"
        )
        let versionCount = try manager.databaseQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM evaluation_versions") ?? 0
        }
        try require(versionCount == 2, "Correcting an evaluation overwrote history or created duplicate records")
    }

    private static func checkPlanningJSONImport() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let manager = try DatabaseManager(databaseURL: directory.appendingPathComponent("import.sqlite"))
        let repository = PlanningImportRepository(databaseQueue: manager.databaseQueue)
        let planID = UUID()
        let activityID = UUID()
        let objectiveID = UUID()
        let occurrenceID = UUID()
        let document = PlanningImportDocument(
            plans: [.init(id: planID.uuidString, title: "Imported Plan", startDate: "2026-10-20", endDate: "2026-10-21")],
            activities: [.init(id: activityID.uuidString, title: "Imported Activity")],
            planActivities: [.init(planID: planID.uuidString, activityID: activityID.uuidString)],
            objectives: [.init(id: objectiveID.uuidString, title: "Imported Objective")],
            planObjectives: [.init(planID: planID.uuidString, objectiveID: objectiveID.uuidString)],
            scheduleOccurrences: [.init(id: occurrenceID.uuidString, activityID: activityID.uuidString, scheduledDate: "2026-10-20")]
        )
        let data = try JSONEncoder().encode(document)
        let preview = try repository.preview(data)
        try require(preview.canImport && preview.totalToAdd == 6, "Import preview did not show all new planning records")
        let result = try repository.importJSON(data)
        try require(result.totalToAdd == 6, "Import result did not report the inserted records")

        let repeated = try repository.preview(data)
        try require(repeated.canImport && repeated.totalToAdd == 0 && repeated.alreadyPresent == 6, "Identical repeated import was not classified as safely skippable")

        let conflictingDocument = PlanningImportDocument(
            plans: [.init(id: planID.uuidString, title: "Conflicting Plan", startDate: "2026-10-20", endDate: "2026-10-21")],
            activities: [.init(id: UUID().uuidString, title: "Would Be Partial")],
            planActivities: [], objectives: [], planObjectives: [], scheduleOccurrences: []
        )
        let conflictData = try JSONEncoder().encode(conflictingDocument)
        let conflictPreview = try repository.preview(conflictData)
        try require(!conflictPreview.canImport && conflictPreview.totalToAdd == 1, "A conflicting identifier was not blocked in preview")
        var rejected = false
        do {
            try repository.importJSON(conflictData)
        } catch PlanningImportError.importHasConflicts {
            rejected = true
        }
        try require(rejected, "A conflicting import was applied")
        let state = PlanningRepository(databaseQueue: manager.databaseQueue)
        try require(try state.plan(id: planID)?.title == "Imported Plan", "Conflict handling overwrote an existing Plan")
        try require(try state.activities().contains(where: { $0.title == "Would Be Partial" }) == false, "A failed import left partial records")
        try require(try state.planObjectives(forPlanID: planID).map(\.objectiveID) == [objectiveID], "Imported Objective relationship was not preserved")
        try require(try state.scheduleOccurrences(forActivityID: activityID).map(\.id) == [occurrenceID], "Imported occurrence was not preserved")
    }

    private static func checkOperationalCommandPersistence() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let databaseURL = directory.appendingPathComponent("commands.sqlite")
        let manager = try DatabaseManager(databaseURL: databaseURL)
        let planning = PlanningRepository(databaseQueue: manager.databaseQueue)
        let commands = OperationalCommandRepository(databaseQueue: manager.databaseQueue)
        let plan = try Plan(title: "Command Plan", startDate: "2026-10-20", endDate: "2026-10-21")
        let activity = try Activity(title: "Review work", details: "Initial details")
        let objective = try Objective(title: "Objective before publish", details: "Target details")
        try planning.create(plan)
        try planning.create(activity)
        try planning.create(objective)

        let parent = try commands.createParentDraft(content: OperationalCommandDraftContent(
            title: "Parent direction",
            details: "First published text",
            classification: "Operational",
            priority: 4,
            effectiveDate: "2026-10-20",
            targets: [
                OperationalCommandTarget(kind: .plan, targetID: plan.id),
                OperationalCommandTarget(kind: .activity, targetID: activity.id),
                OperationalCommandTarget(kind: .objective, targetID: objective.id)
            ]
        ))
        try require(parent.number == "PI-000001" && parent.state == .draft, "Parent command identity or first draft was incorrect")
        let publishedParent = try commands.publish(versionID: parent.id)
        guard let parentSnapshot = publishedParent.snapshot else {
            throw CheckFailure(description: "Publishing a parent command did not save a snapshot")
        }
        try require(parentSnapshot.targets.map(\.title) == ["Command Plan", "Review work", "Objective before publish"], "Parent targets were not snapshotted in their selected order")
        try require(parentSnapshot.date == "2026-10-20", "Parent effective date was not snapshotted")
        let updatedObjective = try Objective(id: objective.id, title: "Objective after publish", details: "Changed target")
        try require(try planning.update(updatedObjective), "Objective source record was not updated")
        try require(
            commands.version(id: parent.id)?.snapshot?.targets.last?.title == "Objective before publish",
            "Changing a source Objective rewrote a published command snapshot"
        )

        let firstOccurrence = try ScheduleOccurrence(
            activityID: activity.id,
            scheduledDate: "2026-10-20",
            startTime: "09:00",
            endTime: "09:30",
            priority: 9
        )
        let nextDayOccurrence = try ScheduleOccurrence(
            activityID: activity.id,
            scheduledDate: "2026-10-21",
            startTime: "10:00",
            endTime: "10:30"
        )
        try planning.schedule(firstOccurrence)
        try planning.schedule(nextDayOccurrence)
        let dailyDraft = try commands.createDailyDraft(
            date: "2026-10-20",
            content: OperationalCommandDraftContent(
                title: "Daily direction",
                items: [OperationalCommandItem(occurrenceID: firstOccurrence.id, parentVersionID: parent.id)]
            )
        )
        try require(dailyDraft.number == "PH-20261020", "Daily command did not use its date-based identity")
        let dailyDraftWithParent = try OperationalCommandDraftContent(
            title: "Daily direction",
            items: [OperationalCommandItem(occurrenceID: firstOccurrence.id, parentVersionID: parent.id)]
        )
        _ = try commands.updateDraft(versionID: dailyDraft.id, content: dailyDraftWithParent, dailyDate: "2026-10-20")
        try require(
            try commands.version(id: dailyDraft.id)?.content.items.first?.parentVersionID == parent.id,
            "Saving a daily draft without changing its date lost its selected parent version"
        )
        let publishedDaily = try commands.publish(versionID: dailyDraft.id)
        guard let dailySnapshot = publishedDaily.snapshot else {
            throw CheckFailure(description: "Publishing a daily command did not save a snapshot")
        }
        try require(
            dailySnapshot.items.count == 1
                && dailySnapshot.items[0].occurrenceID == firstOccurrence.id
                && dailySnapshot.items[0].title == "Review work"
                && dailySnapshot.items[0].priority == 9
                && dailySnapshot.items[0].order == 1
                && dailySnapshot.items[0].parent?.versionID == parent.id,
            "Daily command did not snapshot the selected occurrence, order, priority, and explicit parent version"
        )
        do {
            _ = try commands.createDailyDraft(
                date: "2026-10-20",
                content: OperationalCommandDraftContent(title: "Duplicate daily command")
            )
            throw CheckFailure(description: "A second daily command identity for the same date was accepted")
        } catch is CheckFailure {
            throw CheckFailure(description: "A second daily command identity for the same date was accepted")
        } catch is DatabaseError {
            try require(try commands.commands(kind: .daily).count == 1, "Rejected duplicate daily command left an extra identity")
        }

        let mismatchedDraft = try commands.createDailyDraft(
            date: "2026-10-22",
            content: OperationalCommandDraftContent(
                title: "Second day",
                items: [OperationalCommandItem(occurrenceID: firstOccurrence.id)]
            )
        )
        do {
            _ = try commands.publish(versionID: mismatchedDraft.id)
            throw CheckFailure(description: "A daily command published an occurrence from a different date")
        } catch OperationalCommandValidationError.occurrenceDateMismatch {
            try require(try commands.version(id: mismatchedDraft.id)?.state == .draft, "Failed publication changed draft state")
        }
        let correctedDraft = try OperationalCommandDraftContent(
            title: "Second day",
            items: [OperationalCommandItem(occurrenceID: nextDayOccurrence.id)]
        )
        _ = try commands.updateDraft(versionID: mismatchedDraft.id, content: correctedDraft, dailyDate: "2026-10-21")
        let secondDayPublished = try commands.publish(versionID: mismatchedDraft.id)
        try require(secondDayPublished.number == "PH-20261021", "Editing the daily draft date did not update its draft identity")
        do {
            _ = try commands.updateDraft(
                versionID: secondDayPublished.id,
                content: correctedDraft,
                dailyDate: "2026-10-22"
            )
            throw CheckFailure(description: "A published daily command date was mutable")
        } catch OperationalCommandValidationError.versionIsNotDraft {
            try require(
                try commands.version(id: secondDayPublished.id)?.snapshot?.date == "2026-10-21",
                "A rejected published-date change altered its snapshot"
            )
        }

        let revisionDraft = try commands.createRevision(of: parent.id)
        let revisedContent = try OperationalCommandDraftContent(
            title: "Revised parent direction",
            details: "Second published text",
            classification: "Operational",
            priority: 5,
            effectiveDate: "2026-10-21",
            targets: [OperationalCommandTarget(kind: .objective, targetID: objective.id)]
        )
        _ = try commands.updateDraft(versionID: revisionDraft.id, content: revisedContent)
        let revisedParent = try commands.publish(versionID: revisionDraft.id)
        try require(revisedParent.versionNumber == 2 && revisedParent.snapshot?.title == "Revised parent direction", "Parent revision did not publish as version two")
        let supersededParent = try commands.version(id: parent.id)
        try require(
            supersededParent?.state == .superseded
                && supersededParent?.replacedByVersionID == revisionDraft.id
                && supersededParent?.snapshot == publishedParent.snapshot,
            "Revision did not preserve the previous published version and snapshot"
        )
        do {
            try manager.databaseQueue.write { db in
                try db.execute(
                    sql: "UPDATE operational_command_versions SET snapshot_json = '{}' WHERE id = ?",
                    arguments: [parent.id.uuidString.lowercased()]
                )
            }
            throw CheckFailure(description: "A published command snapshot was mutable")
        } catch is CheckFailure {
            throw CheckFailure(description: "A published command snapshot was mutable")
        } catch is DatabaseError {
            try require(
                try commands.version(id: parent.id)?.snapshot == publishedParent.snapshot,
                "Rejected snapshot mutation changed published history"
            )
        }
        try commands.withdraw(versionID: revisionDraft.id)
        try require(try commands.version(id: revisionDraft.id)?.state == .withdrawn, "Current parent version could not be withdrawn")
        try require(
            try commands.commands(kind: .parent).first?.currentPublishedVersionID == nil,
            "Withdrawn parent version remained current"
        )
        let reopened = try OperationalCommandRepository(
            databaseQueue: DatabaseManager(databaseURL: databaseURL).databaseQueue
        )
        try require(
            try reopened.version(id: dailyDraft.id)?.snapshot == publishedDaily.snapshot,
            "Published daily snapshot did not persist after reopening the database"
        )
    }

    private static func checkSharedObjectivePersistence() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let databaseURL = directory.appendingPathComponent("objectives.sqlite")
        let manager = try DatabaseManager(databaseURL: databaseURL)
        let repository = PlanningRepository(databaseQueue: manager.databaseQueue)
        let firstPlan = try Plan(title: "First Plan", startDate: "2026-10-20", endDate: "2026-10-20")
        let secondPlan = try Plan(title: "Second Plan", startDate: "2026-10-20", endDate: "2026-10-20")
        let objective = try Objective(title: "Improve health", details: "Walk regularly")
        try repository.create(firstPlan)
        try repository.create(secondPlan)
        try repository.create(objective, linkedToPlanID: firstPlan.id)
        try repository.link(objectiveID: objective.id, toPlanID: secondPlan.id)

        try require(try repository.objective(id: objective.id) == objective, "Objective was not persisted")
        try require(try repository.objectives(forPlanID: firstPlan.id) == [objective], "Objective was not linked to its first plan")
        try require(try repository.objectives(forPlanID: secondPlan.id) == [objective], "Objective was not shared with its second plan")
        try require(try repository.objectivesNotLinked(toPlanID: firstPlan.id).isEmpty, "Linked objective remained available to its plan")

        let updatedObjective = try Objective(id: objective.id, title: "Improve wellbeing", details: "Walk most days")
        try require(try repository.update(updatedObjective), "Existing objective was not updated")
        try require(
            try repository.objectives(forPlanID: firstPlan.id) == [updatedObjective]
                && repository.objectives(forPlanID: secondPlan.id) == [updatedObjective],
            "Editing a shared objective did not update the same master record for each plan"
        )

        do {
            try repository.link(objectiveID: objective.id, toPlanID: firstPlan.id)
            throw CheckFailure(description: "Duplicate plan-objective link was accepted")
        } catch is CheckFailure {
            throw CheckFailure(description: "Duplicate plan-objective link was accepted")
        } catch is DatabaseError {
            try require(try repository.objectives(forPlanID: firstPlan.id) == [updatedObjective], "Rejected duplicate changed links")
        }

        do {
            try repository.deleteObjective(id: objective.id)
            throw CheckFailure(description: "Linked objective was deleted")
        } catch is CheckFailure {
            throw CheckFailure(description: "Linked objective was deleted")
        } catch is DatabaseError {
            try require(try repository.objective(id: objective.id) == updatedObjective, "Rejected deletion lost the objective")
        }

        let reopenedManager = try DatabaseManager(databaseURL: databaseURL)
        let reopenedRepository = PlanningRepository(databaseQueue: reopenedManager.databaseQueue)
        try require(try reopenedRepository.objectives(forPlanID: secondPlan.id) == [updatedObjective], "Shared objective did not survive reopening")

        try repository.unlink(objectiveID: objective.id, fromPlanID: firstPlan.id)
        try require(try repository.objective(id: objective.id) == updatedObjective, "Unlinking removed the shared objective")
        try repository.unlink(objectiveID: objective.id, fromPlanID: secondPlan.id)
        try require(try repository.deleteObjective(id: objective.id), "Unlinked objective could not be deleted")
        try require(try repository.objective(id: objective.id) == nil, "Deleted objective remained readable")
        try require(!repository.deleteObjective(id: objective.id), "Deleting a missing objective reported success")

        let candidate = try Objective(title: "Should roll back")
        do {
            try repository.create(candidate, linkedToPlanID: UUID())
            throw CheckFailure(description: "Objective linked to a missing plan unexpectedly succeeded")
        } catch is CheckFailure {
            throw CheckFailure(description: "Objective linked to a missing plan unexpectedly succeeded")
        } catch is DatabaseError {
            try require(try repository.objective(id: candidate.id) == nil, "Failed objective linking left an orphan objective")
        }

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

        let recordedAt = Date(timeIntervalSince1970: 1_797_123_456.75)
        let execution = try ExecutionRecord(
            occurrenceID: firstOccurrence.id,
            recordedAt: recordedAt
        )
        try repository.recordExecution(execution)
        try require(
            try repository.executionRecord(forOccurrenceID: firstOccurrence.id) == execution,
            "Execution record did not preserve its identity, occurrence, and recorded-at timestamp"
        )
        try require(
            try repository.executionRecord(forOccurrenceID: secondOccurrence.id) == nil,
            "An occurrence without an execution record was reported as recorded"
        )
        try require(
            try repository.executionRecords(forActivityID: activity.id) == [execution],
            "Execution records were not listed for their activity"
        )

        do {
            try repository.recordExecution(
                ExecutionRecord(occurrenceID: firstOccurrence.id, recordedAt: recordedAt.addingTimeInterval(1))
            )
            throw CheckFailure(description: "A duplicate execution record was accepted for one occurrence")
        } catch is CheckFailure {
            throw CheckFailure(description: "A duplicate execution record was accepted for one occurrence")
        } catch is DatabaseError {
            try require(
                try repository.executionRecord(forOccurrenceID: firstOccurrence.id) == execution,
                "A rejected duplicate changed the existing execution record"
            )
        }

        do {
            try manager.databaseQueue.write { db in
                try db.execute(
                    sql: "DELETE FROM schedule_occurrences WHERE id = ?",
                    arguments: [firstOccurrence.id.uuidString.lowercased()]
                )
            }
            throw CheckFailure(description: "An occurrence with an execution record was deleted")
        } catch is CheckFailure {
            throw CheckFailure(description: "An occurrence with an execution record was deleted")
        } catch is DatabaseError {
            try require(
                try repository.executionRecord(forOccurrenceID: firstOccurrence.id) == execution,
                "A rejected occurrence deletion changed its execution record"
            )
        }

        do {
            try repository.recordExecution(
                ExecutionRecord(occurrenceID: UUID(), recordedAt: recordedAt)
            )
            throw CheckFailure(description: "An execution record accepted a missing occurrence")
        } catch is CheckFailure {
            throw CheckFailure(description: "An execution record accepted a missing occurrence")
        } catch is DatabaseError {
            // Expected: the occurrence foreign key rejects the record.
        }

        var rejectedInvalidExecutionTimestamp = false
        do {
            _ = try ExecutionRecord(
                occurrenceID: firstOccurrence.id,
                recordedAt: Date(timeIntervalSince1970: .infinity)
            )
        } catch PlanningValidationError.invalidExecutionTimestamp {
            rejectedInvalidExecutionTimestamp = true
        }
        try require(rejectedInvalidExecutionTimestamp, "An invalid execution timestamp was accepted")

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
            try reopenedRepository.executionRecord(forOccurrenceID: firstOccurrence.id) == execution,
            "Execution record did not survive database reopening"
        )
        try require(
            try reopenedRepository.planActivities(forPlanID: secondPlan.id).map(\.activityID) == [activity.id],
            "Plan-activity link did not survive database reopening"
        )
    }

    private static func checkUpgradeFromPopulatedPlanningDatabase() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let databaseURL = directory.appendingPathComponent("upgrade.sqlite")
        let manager = try DatabaseManager(databaseURL: databaseURL)
        let repository = PlanningRepository(databaseQueue: manager.databaseQueue)
        let plan = try Plan(title: "Existing plan", startDate: "2026-10-20", endDate: "2026-10-20")
        let activity = try Activity(title: "Existing activity")
        let occurrence = try ScheduleOccurrence(activityID: activity.id, scheduledDate: "2026-10-20")
        try repository.create(plan)
        try repository.create(activity, linkedToPlanID: plan.id)
        try repository.schedule(occurrence)

        try manager.databaseQueue.write { db in
            try db.execute(sql: "DROP TABLE execution_records")
            try db.execute(sql: "DROP TABLE local_documents")
            try db.execute(sql: "DROP TABLE semantic_vectors")
            try db.execute(sql: "DROP TABLE search_fts")
            try db.execute(sql: "DROP TABLE search_index")
            try db.execute(
                sql: "DELETE FROM grdb_migrations WHERE identifier IN (?, ?, ?)",
                arguments: ["execution_v1", "documents_v1", "search_v1"]
            )
        }

        let upgradedManager = try DatabaseManager(databaseURL: databaseURL)
        let upgradedRepository = PlanningRepository(databaseQueue: upgradedManager.databaseQueue)
        try require(try upgradedRepository.plan(id: plan.id) == plan, "Plan data was lost during execution migration")
        try require(
            try upgradedRepository.activities(forPlanID: plan.id) == [activity],
            "Activity data was lost during execution migration"
        )
        try require(
            try upgradedRepository.scheduleOccurrences(forActivityID: activity.id) == [occurrence],
            "Occurrence data was lost during execution migration"
        )
        try require(
            try upgradedRepository.executionRecord(forOccurrenceID: occurrence.id) == nil,
            "Migration fabricated an execution record for an existing occurrence"
        )
        let documentRepository = DocumentRepository(databaseQueue: upgradedManager.databaseQueue, applicationSupportDirectory: directory)
        try require(try documentRepository.documents().isEmpty, "Document migration introduced an unexpected document")
        let searchRepository = SearchRepository(databaseQueue: upgradedManager.databaseQueue)
        try searchRepository.refreshIndex()
        try require(try searchRepository.textSearch("Existing").contains(where: { $0.title == plan.title }),
                    "Search migration did not index preserved planning data")
    }

    private static func checkUpgradeFromPlanningDatabaseBeforeObjectives() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let databaseURL = directory.appendingPathComponent("objectives-upgrade.sqlite")
        let manager = try DatabaseManager(databaseURL: databaseURL)
        let repository = PlanningRepository(databaseQueue: manager.databaseQueue)
        let plan = try Plan(title: "Existing plan", startDate: "2026-10-20", endDate: "2026-10-20")
        let activity = try Activity(title: "Existing activity")
        try repository.create(plan)
        try repository.create(activity, linkedToPlanID: plan.id)

        try manager.databaseQueue.write { db in
            try db.execute(sql: "DROP TABLE plan_objectives")
            try db.execute(sql: "DROP TABLE objectives")
            try db.execute(
                sql: "DELETE FROM grdb_migrations WHERE identifier = ?",
                arguments: ["objectives_v1"]
            )
        }

        let upgradedManager = try DatabaseManager(databaseURL: databaseURL)
        let upgradedRepository = PlanningRepository(databaseQueue: upgradedManager.databaseQueue)
        try require(try upgradedRepository.plan(id: plan.id) == plan, "Objective migration changed existing plan data")
        try require(try upgradedRepository.activities(forPlanID: plan.id) == [activity], "Objective migration changed existing activity data")
        try require(try upgradedRepository.objectives().isEmpty, "Objective migration created unexpected objective records")
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
