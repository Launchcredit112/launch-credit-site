import SwiftUI

/// The four things Launch does, one per tab — diagnose, build, report, coach —
/// with build and report sharing a tab because they are one job to a member.
/// The account lives behind the avatar on Home, where iOS members look for it.
struct MainTabView: View {
    @State private var selection: Tab = .home

    enum Tab: Hashable { case home, plan, build, coach }

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
        }
        .tint(Brand.green)
    }
}

#Preview {
    MainTabView().environmentObject(AppState())
}
