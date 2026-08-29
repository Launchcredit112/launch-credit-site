import SwiftUI
import LocalAuthentication

struct LoginView: View {
    @EnvironmentObject private var state: AppState
    @Binding var showingSignUp: Bool

    @State private var email = ""
    @State private var password = ""
    @State private var emailError: String?
    @State private var passwordError: String?
    @State private var isWorking = false
    @State private var appeared = false

    @FocusState private var focus: String?
    private enum Field {
        static let email = "email"
        static let password = "password"
    }

    var body: some View {
        ZStack {
            MeshBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    form
                    footer
                }
                .padding(.horizontal, Metrics.gutter)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            if let stored = state.storedEmail, email.isEmpty { email = stored }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.05)) { appeared = true }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 11) {
                BrandMark(size: 46)
                Text("Launch")
                    .font(BrandFont.heading(20))
                    .tracking(-0.4)
                    .foregroundStyle(Brand.ink)
            }
            .padding(.top, 24)

            Headline(plain: "Welcome", italic: "back.", size: 40)

            Text("Sign in to see where your score stands and what to do next.")
                .font(BrandFont.body(16))
                .foregroundStyle(Brand.dim)
                .fixedSize(horizontal: false, vertical: true)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .padding(.bottom, 30)
    }

    // MARK: - Form

    private var form: some View {
        VStack(spacing: 14) {
            BrandField(
                placeholder: "Email address",
                text: $email,
                keyboard: .emailAddress,
                contentType: .username,
                errorMessage: emailError,
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
                errorMessage: passwordError,
                focusBinding: $focus,
                focusID: Field.password
            )
            .submitLabel(.go)
            .onSubmit { attemptSignIn() }

            HStack {
                Spacer()
                Button("Forgot password?") { }
                    .font(BrandFont.body(14, weight: .semibold))
                    .foregroundStyle(Brand.greenDk)
            }
            .padding(.top, -2)

            if let error = state.authError {
                Text(error)
                    .font(BrandFont.body(14, weight: .medium))
                    .foregroundStyle(Brand.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
                    .transition(.opacity)
            }

            Button {
                attemptSignIn()
            } label: {
                HStack(spacing: 10) {
                    if isWorking {
                        ProgressView().tint(.white)
                    }
                    Text(isWorking ? "Signing in…" : "Sign in")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isWorking)
            .padding(.top, 6)

            if state.hasStoredAccount && biometricsAvailable {
                Button {
                    Task {
                        isWorking = true
                        _ = await state.signInWithBiometrics()
                        isWorking = false
                    }
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: biometryIsFaceID ? "faceid" : "touchid")
                        Text("Sign in with \(biometryIsFaceID ? "Face ID" : "Touch ID")")
                    }
                }
                .buttonStyle(LineButtonStyle())
                .disabled(isWorking)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 22)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 22) {
            HStack(spacing: 6) {
                Text("New to Launch?")
                    .font(BrandFont.body(15))
                    .foregroundStyle(Brand.dim)
                Button("Create an account") { showingSignUp = true }
                    .font(BrandFont.body(15, weight: .bold))
                    .foregroundStyle(Brand.greenDk)
            }

            Card(padding: 16, background: Brand.wash.opacity(0.7)) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Brand.greenDk)
                    Text("Checking your credit with Launch is a soft pull. It never lowers your score.")
                        .font(BrandFont.body(13.5, weight: .medium))
                        .foregroundStyle(Brand.dim)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.top, 30)
        .opacity(appeared ? 1 : 0)
    }

    // MARK: - Actions

    private func attemptSignIn() {
        emailError = Validate.email(email) ? nil : "Enter a valid email address."
        passwordError = password.isEmpty ? "Enter your password." : nil
        guard emailError == nil, passwordError == nil else { return }

        focus = nil
        Task {
            isWorking = true
            _ = await state.signIn(email: email, password: password)
            isWorking = false
        }
    }

    private var biometricsAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    private var biometryIsFaceID: Bool {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType == .faceID
    }
}

#Preview {
    NavigationStack {
        LoginView(showingSignUp: .constant(false))
    }
    .environmentObject(AppState())
}
