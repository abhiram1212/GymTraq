import SwiftUI

struct AuthView: View {
    @Environment(AuthViewModel.self) private var vm
    @State private var mode: Mode = .login

    enum Mode { case login, signup }

    var body: some View {
        ZStack {
            AnimatedBackground()

            ScrollView {
                VStack(spacing: 32) {
                    // Logo
                    VStack(spacing: 8) {
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 52, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(red: 0.4, green: 0.7, blue: 1.0),
                                             Color(red: 0.6, green: 0.3, blue: 1.0)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Text("GymTraq")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Your intelligent gym companion")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .padding(.top, 80)

                    // Mode toggle
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
                            GlassTextField(placeholder: "Email", icon: "envelope", text: $bvm.email)
                            GlassTextField(placeholder: "Password", icon: "lock", isSecure: true, text: $bvm.password)

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
                                    else { await vm.signup() }
                                }
                            }
                            .opacity(vm.isLoading ? 0.6 : 1)
                            .disabled(vm.isLoading)

                            if vm.isLoading {
                                ProgressView().tint(.white)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .colorScheme(.dark)
    }
}
