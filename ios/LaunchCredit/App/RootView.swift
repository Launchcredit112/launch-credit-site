import SwiftUI

/// The gate. Nothing in the app is reachable until a member signs in — the
/// first thing anyone sees is the login screen.
struct RootView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        ZStack {
            if state.isRestoring {
                SplashView()
                    .transition(.opacity)
            } else if state.isSignedIn {
                MainTabView()
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
            } else {
                AuthFlowView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: state.isSignedIn)
        .animation(.easeInOut(duration: 0.25), value: state.isRestoring)
        .task { state.restore() }
    }
}

/// Held only for the moment it takes to check for an existing session.
struct SplashView: View {
    @State private var appeared = false

    var body: some View {
        ZStack {
            MeshBackground()
            VStack(spacing: 18) {
                BrandMark(size: 68)
                    .scaleEffect(appeared ? 1 : 0.9)
                    .opacity(appeared ? 1 : 0)
                Text("Launch")
                    .font(BrandFont.heading(28))
                    .tracking(-0.8)
                    .foregroundStyle(Brand.ink)
                    .opacity(appeared ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) { appeared = true }
        }
    }
}

#Preview {
    RootView().environmentObject(AppState())
}
