import SwiftUI

@main
struct MinorityApp: App {
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 8) {
                Text("Minority")
                    .font(.largeTitle)
                Text("System Initialized")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 420, minHeight: 240)
        }
    }
}
