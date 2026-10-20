import Foundation

public struct ApplicationDataResetManager: Sendable {
    public let applicationSupportDirectory: URL

    public init(applicationSupportDirectory: URL) throws {
        let directory = applicationSupportDirectory.standardizedFileURL
        guard directory.lastPathComponent == "Minority",
              directory.deletingLastPathComponent().lastPathComponent == "Application Support" else {
            throw ApplicationDataResetError.invalidApplicationDirectory
        }
        self.applicationSupportDirectory = directory
    }

    public static func applicationManager() throws -> ApplicationDataResetManager {
        let supportDirectory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return try ApplicationDataResetManager(
            applicationSupportDirectory: supportDirectory.appendingPathComponent("Minority", isDirectory: true)
        )
    }

    public func reset(databaseManager: DatabaseManager?) throws {
        if let databaseManager,
           databaseManager.applicationSupportDirectory.standardizedFileURL != applicationSupportDirectory {
            throw ApplicationDataResetError.databaseDirectoryMismatch
        }

        try databaseManager?.databaseQueue.close()
        if FileManager.default.fileExists(atPath: applicationSupportDirectory.path) {
            try FileManager.default.removeItem(at: applicationSupportDirectory)
        }
    }
}

public enum ApplicationDataResetError: Error, Equatable, LocalizedError {
    case invalidApplicationDirectory
    case databaseDirectoryMismatch

    public var errorDescription: String? {
        switch self {
        case .invalidApplicationDirectory:
            "The reset target is not Minority's Application Support directory."
        case .databaseDirectoryMismatch:
            "The open database is not inside Minority's Application Support directory."
        }
    }
}
