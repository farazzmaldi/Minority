import SwiftUI
import MinorityPersistence

@main
struct MinorityApp: App {
    private let planListModel: PlanListModel?
    private let dataResetManager: ApplicationDataResetManager?
    private let initializationError: String?

    init() {
        dataResetManager = try? ApplicationDataResetManager.applicationManager()
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
            LanguageSettingsView(databaseManager: planListModel?.databaseManagerForSettings(), dataResetManager: dataResetManager)
        }
    }
}
