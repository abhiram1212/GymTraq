import SwiftUI

struct SettingsView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss
    @State private var units = UnitSettings.shared
    @State private var vm = ProfileViewModel()
    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 16) {
                    unitsSection
                    passwordSection
                    dangerSection

                    if let msg = vm.successMessage {
                        banner(msg, isError: false)
                            .task(id: msg) {
                                try? await Task.sleep(for: .seconds(4)); vm.successMessage = nil
                            }
                    }
                    if let msg = vm.errorMessage {
                        banner(msg, isError: true)
                            .task(id: msg) {
                                try? await Task.sleep(for: .seconds(5)); vm.errorMessage = nil
                            }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background { AnimatedBackground() }
        .keyboardDoneButton()
        .confirmationDialog(
            "Delete your account?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Account", role: .destructive) {
                Task {
                    if await vm.deleteAccount() {
                        authVM.logout()  // token + caches cleared → app returns to sign-in
                        dismiss()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes your profile, workouts, and chat history. This can't be undone.")
        }
        .colorScheme(.dark)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(10)
                    .background(.white.opacity(0.1), in: Circle())
            }
            Spacer()
            Text("Settings")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            Color.clear.frame(width: 38, height: 38)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    // MARK: - Units

    private var unitsSection: some View {
        GlassCard {
            VStack(spacing: 16) {
                sectionHeader("Units", icon: "ruler")

                HStack {
                    Text("Weight")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Picker("Weight", selection: $units.weight) {
                        ForEach(WeightUnit.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 130)
                }

                HStack {
                    Text("Height")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Picker("Height", selection: $units.height) {
                        ForEach(HeightUnit.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 130)
                }
            }
        }
    }

    // MARK: - Password

    private var passwordSection: some View {
        GlassCard {
            VStack(spacing: 14) {
                @Bindable var bvm = vm
                sectionHeader("Change Password", icon: "lock.rotation")

                secureField("Current password", text: $bvm.currentPassword, contentType: .password)
                secureField("New password (min 8)", text: $bvm.newPassword, contentType: .newPassword)
                secureField("Confirm new password", text: $bvm.confirmPassword, contentType: .newPassword)

                GlassButton(vm.isChangingPassword ? "Updating..." : "Update Password",
                            icon: "checkmark.shield.fill", isPrimary: false) {
                    Task { await vm.changePassword() }
                }
                .disabled(vm.isChangingPassword)
                .opacity(vm.isChangingPassword ? 0.6 : 1)
            }
        }
    }

    // MARK: - Danger

    private var dangerSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Account", icon: "exclamationmark.triangle")

                Button {
                    showDeleteConfirm = true
                } label: {
                    HStack(spacing: 10) {
                        if vm.isDeletingAccount {
                            ProgressView().tint(Color.appDanger)
                        } else {
                            Image(systemName: "trash")
                        }
                        Text("Delete Account").fontWeight(.semibold)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 14)
                    .foregroundStyle(Color.appDanger)
                    .background(Color.appDanger.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(PressableCardStyle())
                .disabled(vm.isDeletingAccount)

                Text("Permanently removes your account and all data.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.appAccent)
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white.opacity(0.7))
                .textCase(.uppercase)
                .tracking(0.5)
            Spacer()
        }
    }

    private func secureField(_ placeholder: String, text: Binding<String>,
                              contentType: UITextContentType) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "lock")
                .foregroundStyle(.white.opacity(0.45))
                .frame(width: 20)
            RevealableSecureField(placeholder: placeholder, text: text, contentType: contentType)
                .foregroundStyle(.white)
        }
        .padding(12)
        .background(Color.appCardElevated,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func banner(_ message: String, isError: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isError ? "exclamationmark.circle" : "checkmark.circle")
            Text(message).font(.subheadline)
            Spacer()
        }
        .foregroundStyle(isError ? Color.appDanger : Color.appSuccess)
        .padding(12)
        .background((isError ? Color.appDanger : Color.appSuccess).opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
