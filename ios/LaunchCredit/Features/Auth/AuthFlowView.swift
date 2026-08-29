import SwiftUI

/// Login first, always. Sign-up is one tap away but never the default —
/// returning members are the common case.
struct AuthFlowView: View {
    @State private var showingSignUp = false

    var body: some View {
        NavigationStack {
            LoginView(showingSignUp: $showingSignUp)
                .navigationDestination(isPresented: $showingSignUp) {
                    SignUpView()
                }
        }
    }
}

#Preview {
    AuthFlowView().environmentObject(AppState())
}
