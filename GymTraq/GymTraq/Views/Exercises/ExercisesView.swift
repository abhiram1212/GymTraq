import SwiftUI

// MARK: - ExercisesView

struct ExercisesView: View {
    @State private var vm = ExercisesViewModel()
    @State private var showAdd = false
    @State private var searchText = ""
    @State private var editTarget: Exercise?
    @State private var deleteTarget: Exercise?

    private var filtered: [Exercise] {
        searchText.isEmpty ? vm.exercises
            : vm.exercises.filter { $0.exercise_name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 2) {
                Text("Exercises")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("\(vm.exercises.count) in your library")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 14)

            // Action failures (delete blocked, rename conflict) while a list is showing
            if let err = vm.errorMessage, !vm.exercises.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle")
                    Text(err).font(.caption)
                    Spacer()
                }
                .foregroundStyle(Color.appDanger)
                .padding(10)
                .background(Color.appDanger.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .task(id: err) {
                    try? await Task.sleep(for: .seconds(5))
                    vm.errorMessage = nil
                }
            }

            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.white.opacity(0.4))
                TextField("Search exercises", text: $searchText).foregroundStyle(.white)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
            .padding(12)
            .background(Color.appCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.white.opacity(0.1), lineWidth: 1))
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            if vm.isLoading {
                Spacer()
                ProgressView().tint(.white)
                Spacer()
            } else if let err = vm.errorMessage, vm.exercises.isEmpty {
                // Network failure — don't disguise it as an empty library
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 50))
                        .foregroundStyle(.white.opacity(0.2))
                    Text("Couldn't load exercises")
                        .foregroundStyle(.white.opacity(0.5))
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.3))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Button {
                        Task { await vm.load() }
                    } label: {
                        Text("Retry")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(.white.opacity(0.12), in: Capsule())
                    }
                    Spacer()
                }
            } else if filtered.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "dumbbell")
                        .font(.system(size: 50))
                        .foregroundStyle(.white.opacity(0.15))
                    Text(searchText.isEmpty ? "No exercises yet" : "No matches")
                        .foregroundStyle(.white.opacity(0.35))
                    Spacer()
                }
            } else if !searchText.isEmpty {
                // Flat list when searching
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filtered) { exercise in
                            exerciseRow(exercise)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
                .scrollIndicators(.hidden)
                .refreshable { await vm.load() }
            } else {
                // Sectioned list by muscle group — grouped in ONE pass instead of
                // re-running the keyword classifier per group per render
                let grouped = Dictionary(grouping: vm.exercises) { muscleGroup(for: $0) }
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                        ForEach(MuscleGroup.allCases, id: \.self) { group in
                            let groupExercises = grouped[group] ?? []
                            if !groupExercises.isEmpty {
                                Section {
                                    LazyVStack(spacing: 8) {
                                        ForEach(groupExercises) { exercise in
                                            exerciseRow(exercise)
                                        }
                                    }
                                    .padding(.top, 8)
                                    .padding(.bottom, 12)
                                } header: {
                                    groupHeader(group: group, count: groupExercises.count)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
                .scrollIndicators(.hidden)
                .refreshable { await vm.load() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .bottomTrailing) {
            fabButton
                .padding(.trailing, 24)
                .padding(.bottom, 16)
        }
        .background { AnimatedBackground() }
        .task { await vm.loadIfNeeded() }
        .sheet(isPresented: $showAdd) {
            AddExerciseSheet(vm: vm)
        }
        .sheet(item: $editTarget) { exercise in
            EditExerciseSheet(vm: vm, exercise: exercise)
        }
        .confirmationDialog(
            "Delete \"\(deleteTarget?.exercise_name ?? "")\"?",
            isPresented: Binding(
                get: { deleteTarget != nil },
                set: { if !$0 { deleteTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let ex = deleteTarget {
                Button("Delete Exercise", role: .destructive) {
                    Task { await vm.delete(ex) }
                    deleteTarget = nil
                }
                Button("Cancel", role: .cancel) { deleteTarget = nil }
            }
        } message: {
            Text("Only possible if no workouts use this exercise.")
        }
        .colorScheme(.dark)
    }

    // MARK: - Row

    @ViewBuilder
    private func exerciseRow(_ exercise: Exercise) -> some View {
        let card = GlassCard(padding: 14) {
            HStack(spacing: 14) {
                let group = muscleGroup(for: exercise)
                Circle()
                    .fill(group.color.opacity(0.15))
                    .frame(width: 34, height: 34)
                    .overlay(
                        Image(systemName: "dumbbell")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(group.color)
                    )
                Text(exercise.exercise_name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                Spacer()
            }
        }
        if exercise.isEditable {
            card.contextMenu {
                Button {
                    editTarget = exercise
                } label: {
                    Label("Edit Exercise", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    deleteTarget = exercise
                } label: {
                    Label("Delete Exercise", systemImage: "trash")
                }
            }
        } else {
            card
        }
    }

    // MARK: - Section header

    private func groupHeader(group: MuscleGroup, count: Int) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(group.color)
                .frame(width: 3, height: 14)
            Text(group.rawValue.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(group.color)
                .tracking(1.2)
            Spacer()
            Text("\(count)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .background(.black.opacity(0.4))
    }

    // MARK: - FAB

    private var fabButton: some View {
        Button { showAdd = true } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 56, height: 56)
                .background(
                    LinearGradient(
                        colors: [Color.appAccent,
                                 Color.appAccentDeep],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())
                .shadow(color: Color.appAccent.opacity(0.5), radius: 16, y: 6)
        }
    }
}

// MARK: - Add Exercise Sheet

struct AddExerciseSheet: View {
    var vm: ExercisesViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selectedGroup: MuscleGroup? = nil
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.3))
                .frame(width: 36, height: 4).padding(.top, 12)

            Text("New Exercise").font(.title2.bold()).foregroundStyle(.white)

            GlassCard {
                VStack(spacing: 16) {
                    GlassTextField(placeholder: "Exercise name", icon: "dumbbell", text: $name)

                    Divider().background(.white.opacity(0.08))

                    // Muscle group picker
                    Menu {
                        ForEach(MuscleGroup.allCases, id: \.self) { group in
                            Button {
                                selectedGroup = group
                            } label: {
                                Text(group.rawValue)
                            }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            if let group = selectedGroup {
                                Circle()
                                    .fill(group.color)
                                    .frame(width: 10, height: 10)
                                Text(group.rawValue)
                                    .foregroundStyle(.white)
                            } else {
                                Image(systemName: "tag")
                                    .foregroundStyle(.white.opacity(0.4))
                                    .frame(width: 20)
                                Text("Muscle Group (optional)")
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .padding(.horizontal, 4)
                    }
                }
            }
            .padding(.horizontal, 20)

            if let err = errorMessage {
                Text(err).font(.caption)
                    .foregroundStyle(Color.appDanger)
                    .padding(.horizontal, 20)
            }

            GlassButton(isLoading ? "Adding..." : "Add Exercise", icon: "plus.circle.fill") {
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                isLoading = true
                errorMessage = nil
                Task {
                    let ok = await vm.create(name: trimmed, muscleGroup: selectedGroup?.rawValue)
                    isLoading = false
                    if ok {
                        dismiss()
                    } else {
                        // Keep the sheet open so the entered name isn't lost
                        errorMessage = vm.errorMessage ?? "Couldn't add the exercise."
                    }
                }
            }
            .disabled(isLoading)
            .opacity(isLoading ? 0.6 : 1)
            .padding(.horizontal, 20)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background { AnimatedBackground() }
        .colorScheme(.dark)
    }
}

// MARK: - Edit Exercise Sheet

struct EditExerciseSheet: View {
    var vm: ExercisesViewModel
    let exercise: Exercise
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var selectedGroup: MuscleGroup?
    @State private var isLoading = false
    @State private var errorMessage: String?

    init(vm: ExercisesViewModel, exercise: Exercise) {
        self.vm = vm
        self.exercise = exercise
        _name = State(initialValue: exercise.exercise_name)
        _selectedGroup = State(initialValue: exercise.muscle_group.flatMap { MuscleGroup(rawValue: $0) })
    }

    var body: some View {
        VStack(spacing: 24) {
            RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.3))
                .frame(width: 36, height: 4).padding(.top, 12)

            Text("Edit Exercise").font(.title2.bold()).foregroundStyle(.white)

            GlassCard {
                VStack(spacing: 16) {
                    GlassTextField(placeholder: "Exercise name", icon: "dumbbell", text: $name)

                    Divider().background(.white.opacity(0.08))

                    Menu {
                        ForEach(MuscleGroup.allCases, id: \.self) { group in
                            Button { selectedGroup = group } label: { Text(group.rawValue) }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            if let group = selectedGroup {
                                Circle().fill(group.color).frame(width: 10, height: 10)
                                Text(group.rawValue).foregroundStyle(.white)
                            } else {
                                Image(systemName: "tag")
                                    .foregroundStyle(.white.opacity(0.4))
                                    .frame(width: 20)
                                Text("Muscle Group (optional)")
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .padding(.horizontal, 4)
                    }
                }
            }
            .padding(.horizontal, 20)

            if let err = errorMessage {
                Text(err).font(.caption)
                    .foregroundStyle(Color.appDanger)
                    .padding(.horizontal, 20)
            }

            GlassButton(isLoading ? "Saving..." : "Save Changes", icon: "checkmark.circle.fill") {
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                isLoading = true
                errorMessage = nil
                Task {
                    let ok = await vm.update(
                        id: exercise.exercise_id,
                        name: trimmed,
                        muscleGroup: selectedGroup?.rawValue
                    )
                    isLoading = false
                    if ok {
                        dismiss()
                    } else {
                        errorMessage = vm.errorMessage ?? "Couldn't save the exercise."
                    }
                }
            }
            .disabled(isLoading)
            .opacity(isLoading ? 0.6 : 1)
            .padding(.horizontal, 20)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background { AnimatedBackground() }
        .colorScheme(.dark)
    }
}
