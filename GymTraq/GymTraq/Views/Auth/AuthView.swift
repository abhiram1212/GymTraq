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
                                colors: [Color.appAccent,
                                         Color.appAccentDeep],
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
                                vm.errorMessage = nil
                                withAnimation(.spring(duration: 0.3)) { mode = m }
                            } label: {
                                Text(m == .login ? "Sign In" : "Create Account")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        mode == m
                                            ? AnyShapeStyle(Color.appCardElevated)
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
                                       isSecure: true, isNewPassword: mode == .signup,
                                       text: $bvm.password)

                        if let err = vm.errorMessage {
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(Color.appDanger)
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
    private enum Step { case email, code, done }

    @Environment(\.dismiss) private var dismiss
    @State private var step: Step = .email
    @State private var email = ""
    @State private var code = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var resendCooldown = 0

    var body: some View {
        VStack(spacing: 24) {
            RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.3))
                .frame(width: 36, height: 4).padding(.top, 12)

            VStack(spacing: 8) {
                Image(systemName: step == .done ? "checkmark.seal.fill" : "lock.rotation")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(Color.appAccent)
                Text("Reset Password")
                    .font(.system(.title2, design: .rounded).bold())
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.subheadline).foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            switch step {
            case .email: emailStep
            case .code:  codeStep
            case .done:  doneStep
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background { AnimatedBackground() }
        .colorScheme(.dark)
    }

    private var subtitle: String {
        switch step {
        case .email: return "Enter your account email and we'll send you a 6-digit code"
        case .code:  return "We sent a code to \(email).\nIt expires in 10 minutes."
        case .done:  return "You're all set"
        }
    }

    // MARK: - Step 1: email

    private var emailStep: some View {
        GlassCard {
            VStack(spacing: 14) {
                GlassTextField(placeholder: "Email", icon: "envelope", text: $email)

                if let err = errorMessage {
                    Text(err).font(.caption)
                        .foregroundStyle(Color.appDanger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                GlassButton(isLoading ? "Sending..." : "Send Code", icon: "paperplane.fill") {
                    sendCode()
                }
                .disabled(isLoading)
                .opacity(isLoading ? 0.6 : 1)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Step 2: code + new password

    private var codeStep: some View {
        GlassCard {
            VStack(spacing: 14) {
                // 6-digit code, big and centered like Apple's verification fields
                TextField("000000", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .tracking(10)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(Color.appCardElevated,
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .onChange(of: code) { _, new in
                        code = String(new.filter(\.isNumber).prefix(6))
                    }

                GlassTextField(placeholder: "New Password", icon: "lock",
                               isSecure: true, isNewPassword: true, text: $newPassword)
                GlassTextField(placeholder: "Confirm Password", icon: "lock.fill",
                               isSecure: true, isNewPassword: true, text: $confirmPassword)

                if let err = errorMessage {
                    Text(err).font(.caption)
                        .foregroundStyle(Color.appDanger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                GlassButton(isLoading ? "Resetting..." : "Reset Password", icon: "lock.rotation") {
                    resetPassword()
                }
                .disabled(isLoading)
                .opacity(isLoading ? 0.6 : 1)

                HStack {
                    Button {
                        step = .email
                        errorMessage = nil
                        code = ""
                    } label: {
                        Label("Change email", systemImage: "chevron.left")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    Spacer()
                    Button {
                        sendCode()
                    } label: {
                        Text(resendCooldown > 0 ? "Resend in \(resendCooldown)s" : "Resend code")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(resendCooldown > 0 ? .white.opacity(0.3) : Color.appAccent)
                    }
                    .disabled(resendCooldown > 0 || isLoading)
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Step 3: done

    private var doneStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.appSuccess)
            Text("Password reset successfully!")
                .font(.headline).foregroundStyle(.white)
            GlassButton("Back to Sign In", icon: "arrow.left.circle.fill") {
                dismiss()
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 20)
    }

    // MARK: - Actions

    private func sendCode() {
        guard email.contains("@") else { errorMessage = "Enter a valid email"; return }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await APIService.shared.requestPasswordReset(email: email)
                step = .code
                startCooldown()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func resetPassword() {
        guard code.count == 6 else { errorMessage = "Enter the 6-digit code"; return }
        guard newPassword.count >= 8 else {
            errorMessage = "Password must be at least 8 characters"; return
        }
        guard newPassword == confirmPassword else {
            errorMessage = "Passwords do not match"; return
        }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await APIService.shared.resetPassword(
                    email: email, code: code, newPassword: newPassword)
                step = .done
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func startCooldown() {
        resendCooldown = 60
        Task {
            while resendCooldown > 0 {
                try? await Task.sleep(for: .seconds(1))
                resendCooldown -= 1
            }
        }
    }
}
