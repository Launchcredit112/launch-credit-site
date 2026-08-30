import SwiftUI

/// The first thing anyone sees. Accounts are created on the web — the checkout
/// there collects the identity and consents the credit partner needs — so the
/// app signs in and gets out of the way.
struct LoginView: View {
    @EnvironmentObject private var state: AppState

    @State private var email = ""
    @State private var password = ""
    @State private var isWorking = false
    @State private var appeared = false

    @FocusState private var focus: String?
    private enum Field {
        static let email = "email"
        static let password = "password"
    }

    /// Accounts are created in the web checkout, which collects the identity
    /// and consents the credit partner needs.
    private static let signUpURL = URL(string: "https://launch.credit/checkout.html")

    private var canSubmit: Bool {
        !email.isEmpty && !password.isEmpty && !isWorking
    }

    var body: some View {
        ZStack {
            MeshBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    header
                    form
                    footer
                }
                .padding(.horizontal, Metrics.gutter)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            if let stored = state.storedEmail, email.isEmpty { email = stored }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.05)) { appeared = true }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 11) {
                BrandMark(size: 46)
                Text("Launch")
                    .font(BrandFont.heading(20))
                    .tracking(-0.4)
                    .foregroundStyle(Brand.ink)
            }
            .padding(.top, 40)

            Headline(plain: "Welcome", italic: "back.", size: 40)

            Text("Sign in to see where your score stands and what to do next.")
                .font(BrandFont.body(16))
                .foregroundStyle(Brand.dim)
                .fixedSize(horizontal: false, vertical: true)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
    }

    private var form: some View {
        VStack(spacing: 14) {
            BrandField(
                placeholder: "Email address",
                text: $email,
                keyboard: .emailAddress,
                contentType: .username,
                focusBinding: $focus,
                focusID: Field.email
            )
            .submitLabel(.next)
            .onSubmit { focus = Field.password }

            BrandField(
                placeholder: "Password",
                text: $password,
                isSecure: true,
                contentType: .password,
                focusBinding: $focus,
                focusID: Field.password
            )
            .submitLabel(.go)
            .onSubmit { attemptSignIn() }

            if let error = state.authError {
                Text(error)
                    .font(BrandFont.body(14, weight: .medium))
                    .foregroundStyle(Brand.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            }

            Button {
                attemptSignIn()
            } label: {
                HStack(spacing: 10) {
                    if isWorking { ProgressView().tint(.white) }
                    Text(isWorking ? "Signing in…" : "Sign in")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!canSubmit)
            .opacity(canSubmit ? 1 : 0.55)
            .padding(.top, 4)
        }
        .animation(.easeOut(duration: 0.2), value: state.authError)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 22)
    }

    private var footer: some View {
        VStack(spacing: 18) {
            HStack(spacing: 5) {
                Text("New to Launch?")
                    .font(BrandFont.body(15))
                    .foregroundStyle(Brand.dim)
                if let signUp = Self.signUpURL {
                    Link("Get started", destination: signUp)
                        .font(BrandFont.body(15, weight: .bold))
                        .tint(Brand.greenDk)
                }
            }

            HStack(alignment: .top, spacing: 11) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Brand.greenDk)
                Text("Checking your credit with Launch is a soft pull. It never lowers your score.")
                    .font(BrandFont.body(13.5, weight: .medium))
                    .foregroundStyle(Brand.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .background(Brand.wash.opacity(0.75), in: RoundedRectangle(cornerRadius: Metrics.radiusTile, style: .continuous))
        }
        .frame(maxWidth: .infinity)
        .opacity(appeared ? 1 : 0)
    }

    private func attemptSignIn() {
        guard canSubmit else { return }
        focus = nil
        Task {
            isWorking = true
            _ = await state.signIn(email: email, password: password)
            isWorking = false
        }
    }
}

#Preview {
    LoginView().environmentObject(AppState())
}
