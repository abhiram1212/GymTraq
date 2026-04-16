import SwiftUI

struct ProfileView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss
    @State private var vm = ProfileViewModel()
    @State private var showPasswordSection = false

    var body: some View {
        VStack(spacing: 0) {
                // Header
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(10)
                            .background(.white.opacity(0.1), in: Circle())
                    }
                    Spacer()
                    Text("Profile")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    // Balance the header
                    Color.clear.frame(width: 38, height: 38)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                ScrollView {
                    VStack(spacing: 16) {
                        // Avatar + email
                        avatarSection

                        // Stats fields
                        if vm.isLoading {
                            ProgressView().tint(.white).padding(.top, 40)
                        } else {
                            statsSection
                            passwordSection
                            signOutSection
                        }

                        // Feedback
                        if let msg = vm.successMessage {
                            feedbackBanner(msg, isError: false)
                        }
                        if let msg = vm.errorMessage {
                            feedbackBanner(msg, isError: true)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background { AnimatedBackground() }
        .task { await vm.load() }
        .colorScheme(.dark)
    }

    // MARK: - Avatar

    private var avatarSection: some View {
        GlassCard {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.2, green: 0.5, blue: 1.0),
                                         Color(red: 0.45, green: 0.2, blue: 0.95)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                    Text(vm.user?.email.prefix(1).uppercased() ?? "?")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(vm.user?.email ?? "—")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text("Member")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                }
                Spacer()
            }
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        GlassCard {
            VStack(spacing: 0) {
                sectionHeader("Body Stats", icon: "person.fill")

                Divider().background(.white.opacity(0.08)).padding(.vertical, 12)

                VStack(spacing: 14) {
                    @Bindable var bvm = vm

                    profileField(label: "Weight (kg)", icon: "scalemass",
                                 placeholder: "e.g. 80", text: $bvm.weightText)
                    profileField(label: "Height (cm)", icon: "ruler",
                                 placeholder: "e.g. 180", text: $bvm.heightText)
                    profileField(label: "Age", icon: "calendar.badge.clock",
                                 placeholder: "e.g. 25", text: $bvm.ageText)

                    // Sex picker
                    HStack(spacing: 12) {
                        Image(systemName: "figure.stand")
                            .foregroundStyle(.white.opacity(0.45))
                            .frame(width: 20)
                        Text("Sex")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                        Spacer()
                        Picker("Sex", selection: $bvm.sex) {
                            Text("—").tag("")
                            Text("Male").tag("male")
                            Text("Female").tag("female")
                            Text("Other").tag("other")
                        }
                        .pickerStyle(.menu)
                        .accentColor(.white.opacity(0.8))
                    }
                }

                Divider().background(.white.opacity(0.08)).padding(.vertical, 12)

                GlassButton(vm.isSaving ? "Saving..." : "Save Changes",
                            icon: "checkmark.circle.fill") {
                    Task { await vm.save() }
                }
                .disabled(vm.isSaving)
                .opacity(vm.isSaving ? 0.6 : 1)
            }
        }
    }

    // MARK: - Password

    private var passwordSection: some View {
        GlassCard {
            VStack(spacing: 0) {
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        showPasswordSection.toggle()
                        vm.errorMessage = nil
                        vm.successMessage = nil
                    }
                } label: {
                    HStack {
                        sectionHeader("Change Password", icon: "lock.rotation")
                        Spacer()
                        Image(systemName: showPasswordSection ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                .buttonStyle(.plain)

                if showPasswordSection {
                    @Bindable var bvm = vm

                    VStack(spacing: 14) {
                        Divider().background(.white.opacity(0.08)).padding(.vertical, 12)

                        secureField(label: "Current Password", icon: "lock",
                                    placeholder: "Enter current password", text: $bvm.currentPassword)
                        secureField(label: "New Password", icon: "lock.open",
                                    placeholder: "At least 6 characters", text: $bvm.newPassword)
                        secureField(label: "Confirm New", icon: "lock.open",
                                    placeholder: "Repeat new password", text: $bvm.confirmPassword)

                        Divider().background(.white.opacity(0.08)).padding(.vertical, 4)

                        GlassButton(
                            vm.isChangingPassword ? "Updating..." : "Update Password",
                            icon: "checkmark.shield.fill",
                            isPrimary: false
                        ) {
                            Task { await vm.changePassword() }
                        }
                        .disabled(vm.isChangingPassword)
                        .opacity(vm.isChangingPassword ? 0.6 : 1)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    // MARK: - Sign Out

    private var signOutSection: some View {
        Button {
            authVM.logout()
            dismiss()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Sign Out")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(Color(red: 1.0, green: 0.35, blue: 0.35))
            .background(Color(red: 1.0, green: 0.35, blue: 0.35).opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(red: 1.0, green: 0.35, blue: 0.35).opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(red: 0.4, green: 0.7, blue: 1.0),
                                 Color(red: 0.6, green: 0.3, blue: 1.0)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white.opacity(0.7))
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func profileField(label: String, icon: String, placeholder: String,
                               text: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.white.opacity(0.45))
                .frame(width: 20)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 100, alignment: .leading)
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
        }
    }

    private func secureField(label: String, icon: String, placeholder: String,
                              text: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.white.opacity(0.45))
                .frame(width: 20)
            SecureField(placeholder, text: text)
                .foregroundStyle(.white)
        }
        .padding(12)
        .background(.white.opacity(0.07),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func feedbackBanner(_ message: String, isError: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isError ? "exclamationmark.circle" : "checkmark.circle")
            Text(message)
                .font(.subheadline)
        }
        .foregroundStyle(isError
            ? Color(red: 1, green: 0.4, blue: 0.4)
            : Color(red: 0.3, green: 0.9, blue: 0.5))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            (isError ? Color(red: 1, green: 0.3, blue: 0.3) : Color(red: 0.2, green: 0.8, blue: 0.4))
                .opacity(0.1),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }
}
