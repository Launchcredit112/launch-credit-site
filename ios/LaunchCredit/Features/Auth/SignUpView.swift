import SwiftUI

/// Mirrors step one of the web checkout: email, password, name, and the
/// consent checkbox. Everything the partner needs beyond that is collected in
/// onboarding, after the account exists.
struct SignUpView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var acceptedTerms = false
    @State private var isWorking = false
    @State private var showValidation = false

    @FocusState private var focus: String?
    private enum Field {
        static let first = "first"
        static let last = "last"
        static let email = "email"
        static let password = "password"
    }

    var body: some View {
        ZStack {
            MeshBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    VStack(alignment: .leading, spacing: 14) {
                        Eyebrow(text: "Create your account")
                        Headline(plain: "Let's get you", italic: "started.", size: 36)
                        Text("Two minutes to start. Then we work.")
                            .font(BrandFont.body(16))
                            .foregroundStyle(Brand.dim)
                    }
                    .padding(.top, 8)

                    VStack(spacing: 14) {
                        HStack(spacing: 12) {
                            BrandField(
                                placeholder: "First name",
                                text: $firstName,
                                contentType: .givenName,
                                autocapitalization: .words,
                                errorMessage: showValidation && !Validate.name(firstName) ? "Required" : nil,
                                focusBinding: $focus,
                                focusID: Field.first
                            )

                            BrandField(
                                placeholder: "Last name",
                                text: $lastName,
                                contentType: .familyName,
                                autocapitalization: .words,
                                errorMessage: showValidation && !Validate.name(lastName) ? "Required" : nil,
                                focusBinding: $focus,
                                focusID: Field.last
                            )
                        }

                        BrandField(
                            placeholder: "Email address",
                            text: $email,
                            keyboard: .emailAddress,
                            contentType: .username,
                            errorMessage: showValidation && !Validate.email(email) ? "Enter a valid email" : nil,
                            focusBinding: $focus,
                            focusID: Field.email
                        )

                        BrandField(
                            placeholder: "Create a password",
                            text: $password,
                            isSecure: true,
                            contentType: .newPassword,
                            errorMessage: showValidation && !Validate.password(password) ? "At least 8 characters, including a number" : nil,
                            focusBinding: $focus,
                            focusID: Field.password
                        )

                        PasswordStrengthBar(password: password)
                    }

                    ConsentCheckbox(isOn: $acceptedTerms)

                    if let error = state.authError {
                        Text(error)
                            .font(BrandFont.body(14, weight: .medium))
                            .foregroundStyle(Brand.red)
                    }

                    Button {
                        attemptSignUp()
                    } label: {
                        HStack(spacing: 10) {
                            if isWorking { ProgressView().tint(.white) }
                            Text(isWorking ? "Creating your account…" : "Create account")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isWorking)

                    Text("$0 today. You're billed $39.99 after each month of work, and you can cancel any time.")
                        .font(BrandFont.body(13))
                        .foregroundStyle(Brand.faint)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, Metrics.gutter)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Label("Back", systemImage: "chevron.left")
                        .font(BrandFont.body(16, weight: .semibold))
                }
                .tint(Brand.ink)
            }
        }
    }

    private var isValid: Bool {
        Validate.name(firstName)
            && Validate.name(lastName)
            && Validate.email(email)
            && Validate.password(password)
            && acceptedTerms
    }

    private func attemptSignUp() {
        showValidation = true
        guard isValid else { return }
        focus = nil
        Task {
            isWorking = true
            _ = await state.signUp(firstName: firstName, lastName: lastName, email: email, password: password)
            isWorking = false
        }
    }
}

// MARK: - Password strength

struct PasswordStrengthBar: View {
    let password: String

    private var score: Int {
        var value = 0
        if password.count >= 8 { value += 1 }
        if password.count >= 12 { value += 1 }
        if password.rangeOfCharacter(from: .decimalDigits) != nil { value += 1 }
        if password.rangeOfCharacter(from: CharacterSet.punctuationCharacters.union(.symbols)) != nil { value += 1 }
        return min(value, 4)
    }

    private var label: String {
        switch score {
        case 0, 1: return "Weak"
        case 2:    return "Okay"
        case 3:    return "Strong"
        default:   return "Very strong"
        }
    }

    private var color: Color {
        switch score {
        case 0, 1: return Brand.red
        case 2:    return Brand.orange
        default:   return Brand.greenBr
        }
    }

    var body: some View {
        if !password.isEmpty {
            HStack(spacing: 10) {
                HStack(spacing: 4) {
                    ForEach(0..<4, id: \.self) { index in
                        Capsule()
                            .fill(index < score ? color : Brand.s3)
                            .frame(height: 4)
                    }
                }
                Text(label)
                    .font(BrandFont.body(12, weight: .bold))
                    .foregroundStyle(color)
                    .frame(width: 78, alignment: .trailing)
            }
            .animation(.easeOut(duration: 0.2), value: score)
        }
    }
}

// MARK: - Consent

/// The site's `.check` row, with the same four documents named.
struct ConsentCheckbox: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isOn ? Brand.green : Brand.s2)
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(isOn ? Brand.green : Brand.line2, lineWidth: 1.4)
                    if isOn {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 22, height: 22)

                Text("I accept Launch's Terms of Service, E-Sign Consent, Privacy Policy and Account Agreement.")
                    .font(BrandFont.body(13.5))
                    .foregroundStyle(Brand.dim)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }
}

#Preview {
    NavigationStack { SignUpView() }.environmentObject(AppState())
}
