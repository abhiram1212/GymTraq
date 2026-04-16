import SwiftUI

struct AuthView: View {
    @Environment(AuthViewModel.self) private var vm
    @State private var mode: Mode = .login
    @State private var showForgotPassword = false

    enum Mode { case login, signup }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {

                // Logo
                VStack(spacing: 8) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 52, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red: 0.4, green: 0.7, blue: 1.0),
                                         Color(red: 0.6, green: 0.3, blue: 1.0)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                    Text("GymTraq")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Your intelligent gym companion")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.top, 60)

                // Sign In / Create Account toggle
                GlassCard(padding: 4) {
                    HStack(spacing: 0) {
                        ForEach([Mode.login, Mode.signup], id: \.self) { m in
                            Button {
                                withAnimation(.spring(duration: 0.3)) { mode = m }
                            } label: {
                                Text(m == .login ? "Sign In" : "Create Account")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        mode == m
                                            ? AnyShapeStyle(.ultraThinMaterial)
                                            : AnyShapeStyle(.clear),
                                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    )
                                    .foregroundStyle(mode == m ? .white : .white.opacity(0.4))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Form
                @Bindable var bvm = vm
                GlassCard {
                    VStack(spacing: 14) {
                        GlassTextField(placeholder: "Email",    icon: "envelope",
                                       text: $bvm.email)
                        GlassTextField(placeholder: "Password", icon: "lock",
                                       isSecure: true, text: $bvm.password)

                        if let err = vm.errorMessage {
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(Color(red: 1, green: 0.4, blue: 0.4))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        GlassButton(
                            mode == .login ? "Sign In" : "Create Account",
                            icon: mode == .login ? "arrow.right.circle.fill" : "person.badge.plus"
                        ) {
                            Task {
                                if mode == .login { await vm.login() }
                                else              { await vm.signup() }
                            }
                        }
                        .opacity(vm.isLoading ? 0.6 : 1)
                        .disabled(vm.isLoading)

                        if vm.isLoading {
                            ProgressView().tint(.white)
                        }

                        if mode == .login {
                            Button("Forgot Password?") {
                                showForgotPassword = true
                            }
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.45))
                            .padding(.top, 4)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxWidth: .infinity)
        .background { AnimatedBackground() }
        .colorScheme(.dark)
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordSheet()
        }
    }
}

// MARK: - Forgot Password Sheet

struct ForgotPasswordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var success = false

    var body: some View {
        VStack(spacing: 24) {
            RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.3))
                .frame(width: 36, height: 4).padding(.top, 12)

            VStack(spacing: 8) {
                Image(systemName: "lock.rotation")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 0.4, green: 0.7, blue: 1.0),
                                     Color(red: 0.6, green: 0.3, blue: 1.0)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                Text("Reset Password")
                    .font(.title2.bold()).foregroundStyle(.white)
                Text("Enter your email and choose a new password")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }

            if success {
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(Color(red: 0.2, green: 0.85, blue: 0.55))
                    Text("Password reset successfully!")
                        .font(.headline).foregroundStyle(.white)
                    GlassButton("Back to Sign In", icon: "arrow.left.circle.fill") {
                        dismiss()
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 20)
            } else {
                GlassCard {
                    VStack(spacing: 14) {
                        GlassTextField(placeholder: "Email", icon: "envelope", text: $email)
                        GlassTextField(placeholder: "New Password", icon: "lock",
                                       isSecure: true, text: $newPassword)
                        GlassTextField(placeholder: "Confirm Password", icon: "lock.fill",
                                       isSecure: true, text: $confirmPassword)

                        if let err = errorMessage {
                            Text(err).font(.caption)
                                .foregroundStyle(Color(red: 1, green: 0.4, blue: 0.4))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        GlassButton(isLoading ? "Resetting..." : "Reset Password",
                                    icon: "lock.rotation") {
                            guard !email.isEmpty else { errorMessage = "Email is required"; return }
                            guard newPassword.count >= 6 else {
                                errorMessage = "Password must be at least 6 characters"; return
                            }
                            guard newPassword == confirmPassword else {
                                errorMessage = "Passwords do not match"; return
                            }
                            isLoading = true; errorMessage = nil
                            Task {
                                do {
                                    try await APIService.shared.forgotPassword(
                                        email: email, newPassword: newPassword)
                                    success = true
                                } catch { errorMessage = error.localizedDescription }
                                isLoading = false
                            }
                        }
                        .disabled(isLoading)
                        .opacity(isLoading ? 0.6 : 1)
                    }
                }
                .padding(.horizontal, 20)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background { AnimatedBackground() }
        .colorScheme(.dark)
    }
}
