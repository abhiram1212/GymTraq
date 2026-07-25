import SwiftUI
import PhotosUI

struct ProfileView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss
    @State private var vm = ProfileViewModel()
    @State private var showPhotoPicker = false
    @State private var showSettings = false
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 16) {
                    heroSection

                    if vm.isLoading {
                        ProgressView().tint(.white).padding(.top, 40)
                    } else {
                        trainingStatsSection
                        bodyStatsSection
                        signOutSection
                    }

                    // Feedback — auto-dismiss so "Profile saved." doesn't linger forever
                    if let msg = vm.successMessage {
                        feedbackBanner(msg, isError: false)
                            .task(id: msg) {
                                try? await Task.sleep(for: .seconds(4))
                                vm.successMessage = nil
                            }
                    }
                    if let msg = vm.errorMessage {
                        feedbackBanner(msg, isError: true)
                            .task(id: msg) {
                                try? await Task.sleep(for: .seconds(5))
                                vm.errorMessage = nil
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
        .task { await vm.load() }
        .keyboardDoneButton()
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data),
                   let jpeg = image.avatarJPEGData() {
                    await vm.uploadPhoto(jpeg)
                }
                photoItem = nil
            }
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
            Text("Profile")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            // Three-dot menu replaces the always-visible Save button
            Menu {
                if vm.isEditing {
                    Button {
                        withAnimation(.spring(duration: 0.3)) { vm.cancelEditing() }
                    } label: {
                        Label("Cancel Editing", systemImage: "xmark")
                    }
                } else {
                    Button {
                        withAnimation(.spring(duration: 0.3)) { vm.beginEditing() }
                    } label: {
                        Label("Edit Profile", systemImage: "pencil")
                    }
                }
                Button {
                    showPhotoPicker = true
                } label: {
                    Label(vm.user?.profile_pic == nil ? "Add Photo" : "Change Photo",
                          systemImage: "photo")
                }
                Divider()
                Button {
                    showSettings = true
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(10)
                    .background(.white.opacity(0.1), in: Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 12) {
            Button { showPhotoPicker = true } label: {
                ZStack(alignment: .bottomTrailing) {
                    AvatarView(user: vm.user, size: 96)
                        .overlay {
                            if vm.isUploadingPhoto {
                                Circle().fill(.black.opacity(0.5))
                                ProgressView().tint(.white)
                            }
                        }
                    // Camera badge signals the avatar is tappable
                    Image(systemName: "camera.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(7)
                        .background(Color.appAccent, in: Circle())
                        .overlay(Circle().stroke(.black, lineWidth: 2.5))
                }
            }
            .buttonStyle(PressableCardStyle())

            VStack(spacing: 4) {
                Text(vm.user?.email ?? "—")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let since = vm.memberSince {
                    Label("Member since \(since)", systemImage: "medal.fill")
                        .font(.caption)
                        .foregroundStyle(Color.appAccent)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Training stats

    private var trainingStatsSection: some View {
        GlassCard {
            VStack(spacing: 12) {
                sectionHeader("Training", icon: "chart.bar.fill")

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())],
                          spacing: 10) {
                    statTile(value: "\(vm.stats.workouts)", label: "Workouts",
                             icon: "figure.strengthtraining.traditional", tint: Color.appAccent)
                    statTile(value: "\(vm.stats.totalSets)", label: "Total Sets",
                             icon: "square.stack.3d.up.fill", tint: Color.appSuccess)
                    statTile(value: "\(vm.stats.volumeLabel) kg", label: "Volume Lifted",
                             icon: "scalemass.fill", tint: .orange)
                    statTile(value: "\(vm.stats.thisWeek)", label: "This Week",
                             icon: "calendar", tint: Color.appDanger)
                }

                if let favorite = vm.stats.favoriteExercise {
                    HStack(spacing: 10) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.yellow)
                        Text("Favorite exercise")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                        Spacer()
                        Text(favorite)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(12)
                    .background(Color.appCardElevated,
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }

    private func statTile(value: String, label: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .animation(.snappy, value: value)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.appCardElevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Body stats (view / edit)

    private var bodyStatsSection: some View {
        GlassCard {
            VStack(spacing: 0) {
                HStack {
                    sectionHeader("Body Stats", icon: "person.fill")
                    if vm.isEditing {
                        Text("EDITING")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.appAccent, in: Capsule())
                    }
                }

                Divider().background(.white.opacity(0.08)).padding(.vertical, 12)

                if vm.isEditing {
                    editFields
                } else {
                    displayRows
                }
            }
        }
    }

    private var displayRows: some View {
        let units = UnitSettings.shared
        return VStack(spacing: 14) {
            displayRow(label: "Weight", icon: "scalemass",
                       value: vm.user?.weight.map { units.weightLabel(fromKg: $0) })
            displayRow(label: "Height", icon: "ruler",
                       value: vm.user?.height.map { units.heightLabel(fromCm: $0) })
            displayRow(label: "Age", icon: "calendar.badge.clock",
                       value: vm.user?.age.map { "\($0)" })
            displayRow(label: "Sex", icon: "figure.stand",
                       value: vm.user?.sex?.capitalized)

            if let bmi = vm.bmi {
                HStack(spacing: 10) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.appSuccess)
                    Text("BMI")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                    Spacer()
                    Text(String(format: "%.1f", bmi.value))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                    Text(bmi.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.appSuccess)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.appSuccess.opacity(0.15), in: Capsule())
                }
                .padding(12)
                .background(Color.appCardElevated,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private func displayRow(label: String, icon: String, value: String?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.white.opacity(0.45))
                .frame(width: 20)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
            Text(value ?? "—")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(value == nil ? .white.opacity(0.3) : .white)
        }
    }

    private var editFields: some View {
        let units = UnitSettings.shared
        return VStack(spacing: 14) {
            @Bindable var bvm = vm

            profileField(label: "Weight (\(units.weight.label))", icon: "scalemass",
                         placeholder: units.weight == .kg ? "e.g. 80" : "e.g. 176",
                         text: $bvm.weightText)

            // Height entry adapts to the unit: single cm field, or feet + inches
            if units.height == .cm {
                profileField(label: "Height (cm)", icon: "ruler",
                             placeholder: "e.g. 180", text: $bvm.heightText)
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "ruler")
                        .foregroundStyle(.white.opacity(0.45))
                        .frame(width: 20)
                    Text("Height")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                    Spacer()
                    TextField("ft", text: $bvm.feetText)
                        .keyboardType(.numberPad)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 44)
                    Text("ft").font(.caption).foregroundStyle(.white.opacity(0.4))
                    TextField("in", text: $bvm.inchesText)
                        .keyboardType(.numberPad)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 44)
                    Text("in").font(.caption).foregroundStyle(.white.opacity(0.4))
                }
            }

            profileField(label: "Age", icon: "calendar.badge.clock",
                         placeholder: "e.g. 25", text: $bvm.ageText)

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
                .tint(.white.opacity(0.8))
            }

            Divider().background(.white.opacity(0.08)).padding(.vertical, 4)

            HStack(spacing: 10) {
                GlassButton("Cancel", isPrimary: false) {
                    withAnimation(.spring(duration: 0.3)) { vm.cancelEditing() }
                }
                GlassButton(vm.isSaving ? "Saving..." : "Save", icon: "checkmark") {
                    Task { await vm.save() }
                }
                .disabled(vm.isSaving)
                .opacity(vm.isSaving ? 0.6 : 1)
            }
        }
    }

    private func trimmed(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
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
            .foregroundStyle(Color.appDanger)
            .background(Color.appDanger.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(PressableCardStyle())
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

    private func feedbackBanner(_ message: String, isError: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isError ? "exclamationmark.circle" : "checkmark.circle")
            Text(message)
                .font(.subheadline)
        }
        .foregroundStyle(isError ? Color.appDanger : Color.appSuccess)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            (isError ? Color.appDanger : Color.appSuccess).opacity(0.1),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }
}
