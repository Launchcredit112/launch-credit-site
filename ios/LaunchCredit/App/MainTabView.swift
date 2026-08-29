import SwiftUI

/// The four things Launch does — diagnose, build, coach, and the plan behind
/// them — plus the member's account.
struct MainTabView: View {
    @EnvironmentObject private var state: AppState
    @State private var selection: Tab = .home

    enum Tab: Hashable { case home, plan, build, coach, you }

    var body: some View {
        TabView(selection: $selection) {
            HomeView(selection: $selection)
                .tabItem { Label("Home", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(Tab.home)

            PlanView()
                .tabItem { Label("Plan", systemImage: "list.bullet.rectangle") }
                .tag(Tab.plan)

            BuildView()
                .tabItem { Label("Build", systemImage: "building.columns.fill") }
                .tag(Tab.build)

            CoachView()
                .tabItem { Label("Coach", systemImage: "bubble.left.and.text.bubble.right.fill") }
                .tag(Tab.coach)

            ProfileView()
                .tabItem { Label("You", systemImage: "person.crop.circle") }
                .tag(Tab.you)
        }
        .tint(Brand.green)
    }
}

#Preview {
    MainTabView().environmentObject(AppState())
}
