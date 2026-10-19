import SwiftUI
import MinorityPersistence

@main
struct MinorityApp: App {
    private let planListModel: PlanListModel?
    private let initializationError: String?

    init() {
        do {
            let databaseManager = try DatabaseManager.applicationDatabase()
            planListModel = PlanListModel(databaseManager: databaseManager)
            initializationError = nil
        } catch {
            planListModel = nil
            initializationError = error.localizedDescription
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let planListModel {
                    PlanListView(model: planListModel)
                } else {
                    DatabaseUnavailableView(error: initializationError)
                }
            }
            .frame(minWidth: 420, minHeight: 240)
        }

        Settings {
            LanguageSettingsView()
        }
    }
}
