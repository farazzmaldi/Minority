import Foundation

public struct PlanningImportDocument: Codable, Sendable {
    public let format: String
    public let version: Int
    public let plans: [PlanItem]
    public let activities: [ActivityItem]
    public let planActivities: [PlanActivityItem]
    public let objectives: [ObjectiveItem]
    public let planObjectives: [PlanObjectiveItem]
    public let scheduleOccurrences: [ScheduleOccurrenceItem]

    public init(
        format: String = "minority.planning",
        version: Int = 1,
        plans: [PlanItem], activities: [ActivityItem], planActivities: [PlanActivityItem],
        objectives: [ObjectiveItem], planObjectives: [PlanObjectiveItem], scheduleOccurrences: [ScheduleOccurrenceItem]
    ) {
        self.format = format
        self.version = version
        self.plans = plans
        self.activities = activities
        self.planActivities = planActivities
        self.objectives = objectives
        self.planObjectives = planObjectives
        self.scheduleOccurrences = scheduleOccurrences
    }

    private enum CodingKeys: String, CodingKey {
        case format, version, plans, activities, planActivities, objectives, planObjectives, scheduleOccurrences
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        format = try values.decode(String.self, forKey: .format)
        version = try values.decode(Int.self, forKey: .version)
        plans = try values.decodeIfPresent([PlanItem].self, forKey: .plans) ?? []
        activities = try values.decodeIfPresent([ActivityItem].self, forKey: .activities) ?? []
        planActivities = try values.decodeIfPresent([PlanActivityItem].self, forKey: .planActivities) ?? []
        objectives = try values.decodeIfPresent([ObjectiveItem].self, forKey: .objectives) ?? []
        planObjectives = try values.decodeIfPresent([PlanObjectiveItem].self, forKey: .planObjectives) ?? []
        scheduleOccurrences = try values.decodeIfPresent([ScheduleOccurrenceItem].self, forKey: .scheduleOccurrences) ?? []
    }

    public struct PlanItem: Codable, Sendable {
        public let id: String
        public let title: String
        public let startDate: String
        public let endDate: String
        public init(id: String, title: String, startDate: String, endDate: String) {
            self.id = id; self.title = title; self.startDate = startDate; self.endDate = endDate
        }
    }

    public struct ActivityItem: Codable, Sendable {
        public let id: String
        public let title: String
        public let details: String?
        public init(id: String, title: String, details: String? = nil) {
            self.id = id; self.title = title; self.details = details
        }
    }

    public struct PlanActivityItem: Codable, Sendable {
        public let planID: String
        public let activityID: String
        public init(planID: String, activityID: String) { self.planID = planID; self.activityID = activityID }
    }

    public struct ObjectiveItem: Codable, Sendable {
        public let id: String
        public let title: String
        public let details: String?
        public init(id: String, title: String, details: String? = nil) {
            self.id = id; self.title = title; self.details = details
        }
    }

    public struct PlanObjectiveItem: Codable, Sendable {
        public let planID: String
        public let objectiveID: String
        public init(planID: String, objectiveID: String) { self.planID = planID; self.objectiveID = objectiveID }
    }

    public struct ScheduleOccurrenceItem: Codable, Sendable {
        public let id: String
        public let activityID: String
        public let scheduledDate: String
        public let startTime: String?
        public let endTime: String?
        public let priority: Int?
        public init(id: String, activityID: String, scheduledDate: String, startTime: String? = nil, endTime: String? = nil, priority: Int? = nil) {
            self.id = id; self.activityID = activityID; self.scheduledDate = scheduledDate
            self.startTime = startTime; self.endTime = endTime; self.priority = priority
        }
    }
}

public struct PlanningImportSummary: Equatable, Sendable {
    public let plansToAdd: Int
    public let activitiesToAdd: Int
    public let linksToAdd: Int
    public let objectivesToAdd: Int
    public let objectiveLinksToAdd: Int
    public let occurrencesToAdd: Int
    public let alreadyPresent: Int
    public let issues: [String]
    public let planTitles: [String]
    public let activityTitles: [String]
    public let objectiveTitles: [String]
    public let occurrenceDates: [String]

    public var canImport: Bool { issues.isEmpty }
    public var totalToAdd: Int {
        plansToAdd + activitiesToAdd + linksToAdd + objectivesToAdd + objectiveLinksToAdd + occurrencesToAdd
    }
}

public enum PlanningImportError: Error, Equatable, LocalizedError {
    case unsupportedFormat
    case unsupportedVersion(Int)
    case invalidIdentifier(String)
    case duplicateIdentifier(String)
    case duplicateRelationship(String)
    case importHasConflicts([String])

    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat: "This is not a Minority planning JSON file."
        case let .unsupportedVersion(version): "Planning JSON version \(version) is not supported."
        case let .invalidIdentifier(value): "Invalid record identifier: \(value)."
        case let .duplicateIdentifier(value): "The import contains a repeated record identifier: \(value)."
        case let .duplicateRelationship(value): "The import contains a repeated relationship: \(value)."
        case let .importHasConflicts(issues): "The import was not applied. Resolve these conflicts first: \(issues.joined(separator: "; "))"
        }
    }
}
