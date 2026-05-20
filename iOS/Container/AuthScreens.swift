import SwiftUI

struct SignUpForm: View {
    @EnvironmentObject private var session: UserSession
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false
    @FocusState private var focusedField: AuthField?

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && email.contains("@")
            && password.count >= 6
            && !isSubmitting
    }

    var body: some View {
        AuthFormScaffold(
            title: "Create your account",
            subtitle: "Type Japanese and English without switching."
        ) { scale in
            VStack(spacing: 16 * scale) {
                AuthTextField(
                    placeholder: "Name",
                    text: $name,
                    scale: scale,
                    field: .name,
                    focused: $focusedField
                )
                AuthTextField(
                    placeholder: "Email",
                    text: $email,
                    scale: scale,
                    keyboard: .emailAddress,
                    autocapitalization: .never,
                    field: .email,
                    focused: $focusedField
                )
                AuthSecureField(
                    placeholder: "Password (6+ characters)",
                    text: $password,
                    scale: scale,
                    field: .password,
                    focused: $focusedField
                )
            }
        } footer: { scale in
            VStack(spacing: 14 * scale) {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 14 * scale, weight: .regular, design: .rounded))
                        .foregroundStyle(Color(red: 0.78, green: 0.22, blue: 0.30))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12 * scale)
                }

                Button(action: submit) {
                    OnboardingPrimaryButtonLabel(
                        title: "Create account",
                        scale: scale,
                        isLoading: isSubmitting,
                        isEnabled: canSubmit
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
            }
        }
    }

    private func submit() {
        focusedField = nil
        errorMessage = nil
        isSubmitting = true
        Task {
            defer { isSubmitting = false }
            do {
                try await session.signUp(
                    name: name.trimmingCharacters(in: .whitespaces),
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct SignInForm: View {
    @EnvironmentObject private var session: UserSession
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false
    @FocusState private var focusedField: AuthField?

    private var canSubmit: Bool {
        email.contains("@") && !password.isEmpty && !isSubmitting
    }

    var body: some View {
        AuthFormScaffold(
            title: "Welcome back",
            subtitle: "Sign in to keep your conversions in sync."
        ) { scale in
            VStack(spacing: 16 * scale) {
                AuthTextField(
                    placeholder: "Email",
                    text: $email,
                    scale: scale,
                    keyboard: .emailAddress,
                    autocapitalization: .never,
                    field: .email,
                    focused: $focusedField
                )
                AuthSecureField(
                    placeholder: "Password",
                    text: $password,
                    scale: scale,
                    field: .password,
                    focused: $focusedField
                )
            }
        } footer: { scale in
            VStack(spacing: 14 * scale) {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 14 * scale, weight: .regular, design: .rounded))
                        .foregroundStyle(Color(red: 0.78, green: 0.22, blue: 0.30))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12 * scale)
                }

                Button(action: submit) {
                    OnboardingPrimaryButtonLabel(
                        title: "Sign in",
                        scale: scale,
                        isLoading: isSubmitting,
                        isEnabled: canSubmit
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
            }
        }
    }

    private func submit() {
        focusedField = nil
        errorMessage = nil
        isSubmitting = true
        Task {
            defer { isSubmitting = false }
            do {
                try await session.signIn(
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

enum AuthField: Hashable {
    case name
    case email
    case password
}

private struct AuthFormScaffold<Content: View, Footer: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: (CGFloat) -> Content
    @ViewBuilder let footer: (CGFloat) -> Footer

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / 390, proxy.size.height / 844)

            ZStack {
                OnboardingBackground()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    AuthBackButton(scale: scale, action: { dismiss() })
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 28 * scale)
                        .padding(.top, 8 * scale)

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 28 * scale) {
                            VStack(alignment: .leading, spacing: 10 * scale) {
                                Text(title)
                                    .font(.system(size: 34 * scale, weight: .semibold, design: .rounded))
                                    .foregroundStyle(AppColor.ink)

                                Text(subtitle)
                                    .font(.system(size: 16 * scale, weight: .regular, design: .rounded))
                                    .foregroundStyle(AppColor.muted)
                                    .lineSpacing(3 * scale)
                            }

                            content(scale)
                        }
                        .padding(.horizontal, 28 * scale)
                        .padding(.top, 24 * scale)
                        .padding(.bottom, 36 * scale)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    footer(scale)
                        .padding(.horizontal, 28 * scale)
                        .padding(.bottom, 32 * scale)
                }
            }
            .preferredColorScheme(.light)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct AuthBackButton: View {
    let scale: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color.white.opacity(0.76))
                .frame(width: 44 * scale, height: 44 * scale)
                .overlay {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17 * scale, weight: .semibold))
                        .foregroundStyle(AppColor.ink)
                }
                .shadow(color: .black.opacity(0.05), radius: 12 * scale, x: 0, y: 6 * scale)
        }
        .buttonStyle(.plain)
    }
}

private struct AuthTextField: View {
    let placeholder: String
    @Binding var text: String
    let scale: CGFloat
    var keyboard: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences
    let field: AuthField
    var focused: FocusState<AuthField?>.Binding

    var body: some View {
        TextField("", text: $text, prompt: Text(placeholder).foregroundColor(AppColor.softText))
            .keyboardType(keyboard)
            .textInputAutocapitalization(autocapitalization)
            .autocorrectionDisabled(true)
            .focused(focused, equals: field)
            .foregroundStyle(AppColor.ink)
            .font(.system(size: 16 * scale, weight: .regular, design: .rounded))
            .padding(.horizontal, 22 * scale)
            .frame(height: 56 * scale)
            .background(.white, in: RoundedRectangle(cornerRadius: 18 * scale, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18 * scale, style: .continuous)
                    .stroke(
                        focused.wrappedValue == field
                            ? AppColor.purple.opacity(0.65)
                            : AppColor.lavender.opacity(0.6),
                        lineWidth: 1.4
                    )
            )
            .shadow(color: .black.opacity(0.035), radius: 12 * scale, x: 0, y: 6 * scale)
    }
}

private struct AuthSecureField: View {
    let placeholder: String
    @Binding var text: String
    let scale: CGFloat
    let field: AuthField
    var focused: FocusState<AuthField?>.Binding

    var body: some View {
        SecureField("", text: $text, prompt: Text(placeholder).foregroundColor(AppColor.softText))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .focused(focused, equals: field)
            .foregroundStyle(AppColor.ink)
            .font(.system(size: 16 * scale, weight: .regular, design: .rounded))
            .padding(.horizontal, 22 * scale)
            .frame(height: 56 * scale)
            .background(.white, in: RoundedRectangle(cornerRadius: 18 * scale, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18 * scale, style: .continuous)
                    .stroke(
                        focused.wrappedValue == field
                            ? AppColor.purple.opacity(0.65)
                            : AppColor.lavender.opacity(0.6),
                        lineWidth: 1.4
                    )
            )
            .shadow(color: .black.opacity(0.035), radius: 12 * scale, x: 0, y: 6 * scale)
    }
}
