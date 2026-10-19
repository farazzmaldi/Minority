import SwiftUI
import MinorityPersistence

@main
struct MinorityApp: App {
    private let databaseManager: DatabaseManager?
    private let initializationError: String?

    init() {
        do {
            databaseManager = try DatabaseManager.applicationDatabase()
            initializationError = nil
        } catch {
            databaseManager = nil
            initializationError = error.localizedDescription
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if databaseManager != nil {
                    VStack(spacing: 8) {
                        Text("Minority")
                            .font(.largeTitle)
                        Text("System Initialized")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    VStack(spacing: 12) {
                        Text("Minority")
                            .font(.largeTitle)
                        Text("Database Unavailable")
                            .font(.title2)
                        Text("The local database could not be opened. Your existing data has not been reset.")
                            .foregroundStyle(.secondary)
                        if let initializationError {
                            Text(initializationError)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                    .padding()
                }
            }
            .frame(minWidth: 420, minHeight: 240)
        }
    }
}
