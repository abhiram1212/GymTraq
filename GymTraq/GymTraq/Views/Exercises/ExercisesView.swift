import SwiftUI

// MARK: - ExercisesView

struct ExercisesView: View {
    @State private var vm = ExercisesViewModel()
    @State private var showAdd = false
    @State private var searchText = ""

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
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.white.opacity(0.1), lineWidth: 1))
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            if vm.isLoading {
                Spacer()
                ProgressView().tint(.white)
                Spacer()
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
            } else {
                // Sectioned list by muscle group
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                        ForEach(MuscleGroup.allCases, id: \.self) { group in
                            let groupExercises = vm.exercises.filter { muscleGroup(for: $0) == group }
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
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .bottomTrailing) {
            fabButton
                .padding(.trailing, 24)
                .padding(.bottom, 16)
        }
        .background { AnimatedBackground() }
        .task { await vm.load() }
        .sheet(isPresented: $showAdd) {
            AddExerciseSheet(vm: vm)
        }
        .colorScheme(.dark)
    }

    // MARK: - Row

    private func exerciseRow(_ exercise: Exercise) -> some View {
        GlassCard(padding: 14) {
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
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.2, green: 0.5, blue: 1.0),
                                 Color(red: 0.45, green: 0.2, blue: 0.95)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())
                .shadow(color: Color(red: 0.3, green: 0.4, blue: 1.0).opacity(0.5), radius: 16, y: 6)
        }
    }
}

// MARK: - Add Exercise Sheet

struct AddExerciseSheet: View {
    var vm: ExercisesViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selectedGroup: MuscleGroup? = nil

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

            GlassButton("Add Exercise", icon: "plus.circle.fill") {
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                Task {
                    await vm.create(name: trimmed, muscleGroup: selectedGroup?.rawValue)
                    dismiss()
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background { AnimatedBackground() }
        .colorScheme(.dark)
    }
}
