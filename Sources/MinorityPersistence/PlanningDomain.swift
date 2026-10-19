import Foundation

public enum PlanningValidationError: Error, Equatable, LocalizedError {
    case emptyTitle
    case invalidDate(String)
    case invalidTime(String)
    case invalidDateRange
    case incompleteTimeRange
    case invalidTimeRange

    public var errorDescription: String? {
        switch self {
        case .emptyTitle:
            return "A title is required."
        case let .invalidDate(value):
            return "Invalid calendar date: \(value). Use YYYY-MM-DD."
        case let .invalidTime(value):
            return "Invalid local time: \(value). Use HH:mm."
        case .invalidDateRange:
            return "The plan end date must not be before its start date."
        case .incompleteTimeRange:
            return "A scheduled start and end time must both be provided, or both omitted."
        case .invalidTimeRange:
            return "The scheduled end time must be later than its start time on the same date."
        }
    }
}

public struct Plan: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let startDate: String
    public let endDate: String

    public init(id: UUID = UUID(), title: String, startDate: String, endDate: String) throws {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTitle.isEmpty else { throw PlanningValidationError.emptyTitle }
        try Self.validateDate(startDate)
        try Self.validateDate(endDate)
        guard startDate <= endDate else { throw PlanningValidationError.invalidDateRange }

        self.id = id
        self.title = normalizedTitle
        self.startDate = startDate
        self.endDate = endDate
    }

    static func validateDate(_ value: String) throws {
        let bytes = Array(value.utf8)
        guard bytes.count == 10,
              bytes[4] == 45,
              bytes[7] == 45,
              bytes.enumerated().allSatisfy({ index, byte in
                  index == 4 || index == 7 || (48...57).contains(byte)
              }),
              let year = Int(value.prefix(4)),
              let month = Int(value.dropFirst(5).prefix(2)),
              let day = Int(value.suffix(2)),
              (1...9999).contains(year),
              (1...12).contains(month) else {
            throw PlanningValidationError.invalidDate(value)
        }

        let leapYear = year.isMultiple(of: 4) && (!year.isMultiple(of: 100) || year.isMultiple(of: 400))
        let daysPerMonth = [31, leapYear ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        guard (1...daysPerMonth[month - 1]).contains(day) else {
            throw PlanningValidationError.invalidDate(value)
        }
    }
}

public struct Activity: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let details: String?

    public init(id: UUID = UUID(), title: String, details: String? = nil) throws {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTitle.isEmpty else { throw PlanningValidationError.emptyTitle }

        self.id = id
        self.title = normalizedTitle
        self.details = details?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }
}

public struct PlanActivity: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let planID: UUID
    public let activityID: UUID

    public init(id: UUID = UUID(), planID: UUID, activityID: UUID) {
        self.id = id
        self.planID = planID
        self.activityID = activityID
    }
}

public struct ScheduleOccurrence: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let activityID: UUID
    public let scheduledDate: String
    public let startTime: String?
    public let endTime: String?
    public let priority: Int?

    public init(
        id: UUID = UUID(),
        activityID: UUID,
        scheduledDate: String,
        startTime: String? = nil,
        endTime: String? = nil,
        priority: Int? = nil
    ) throws {
        try Plan.validateDate(scheduledDate)
        guard (startTime == nil) == (endTime == nil) else {
            throw PlanningValidationError.incompleteTimeRange
        }
        if let startTime, let endTime {
            try Self.validateTime(startTime)
            try Self.validateTime(endTime)
            guard endTime > startTime else { throw PlanningValidationError.invalidTimeRange }
        }

        self.id = id
        self.activityID = activityID
        self.scheduledDate = scheduledDate
        self.startTime = startTime
        self.endTime = endTime
        self.priority = priority
    }

    private static func validateTime(_ value: String) throws {
        let bytes = Array(value.utf8)
        guard bytes.count == 5,
              bytes[2] == 58,
              bytes.enumerated().allSatisfy({ index, byte in
                  index == 2 || (48...57).contains(byte)
              }),
              let hour = Int(value.prefix(2)),
              let minute = Int(value.suffix(2)),
              (0...23).contains(hour),
              (0...59).contains(minute) else {
            throw PlanningValidationError.invalidTime(value)
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
