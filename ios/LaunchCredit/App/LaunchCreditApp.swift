import SwiftUI

@main
struct LaunchCreditApp: App {
    @StateObject private var state = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .tint(Brand.green)
                // The whole brand is a light theme; don't let dark mode invert it.
                .preferredColorScheme(.light)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { state.persistMemberData() }
        }
    }
}
