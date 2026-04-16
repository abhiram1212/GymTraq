import SwiftUI

// MARK: - Session Detail

struct SessionDetailView: View {
    @State private var session: WorkoutSession
    var onUpdate: ((WorkoutSession) -> Void)?
    @State private var entries: [Entry] = []
    @State private var exercises: [Exercise] = []
    @State private var exerciseOrder: [Int] = []
    @State private var isLoading = false
    @State private var showEditSession = false
    @State private var showAddExercise = false
    @State private var addSetTarget: Exercise?
    @State private var replaceTarget: ReplaceTarget?
    @Environment(\.dismiss) private var dismiss

    init(session: WorkoutSession, onUpdate: ((WorkoutSession) -> Void)? = nil) {
        _session = State(initialValue: session)
        self.onUpdate = onUpdate
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if let notes = session.notes, !notes.isEmpty {
                GlassCard(padding: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "note.text")
                            .foregroundStyle(.white.opacity(0.4))
                        Text(notes)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
            }

            if !entries.isEmpty { statsRow }

            if isLoading {
                Spacer()
                ProgressView().tint(.white)
                Spacer()
            } else if exerciseOrder.isEmpty {
                emptyState
            } else {
                exerciseList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .bottomTrailing) {
            addFAB
                .padding(.trailing, 24)
                .padding(.bottom, 16)
        }
        .background { AnimatedBackground() }
        .task { await loadData() }
        .sheet(isPresented: $showEditSession) {
            EditSessionSheet(session: session) { updated in
                session = updated
                onUpdate?(updated)
            }
        }
        .sheet(isPresented: $showAddExercise) {
            AddEntrySheet(session: session, exercises: exercises, currentEntries: entries) { newEntry in
                entries.append(newEntry)
                if !exerciseOrder.contains(newEntry.exercise_id) {
                    exerciseOrder.append(newEntry.exercise_id)
                }
            }
        }
        .sheet(item: $addSetTarget) { exercise in
            AddSetSheet(
                session: session,
                exercise: exercise,
                setNumber: nextSetNumber(for: exercise.exercise_id)
            ) { newEntry in
                entries.append(newEntry)
            }
        }
        .sheet(item: $replaceTarget) { target in
            ReplaceExerciseSheet(
                session: session,
                exercises: exercises,
                currentExerciseId: target.id
            ) { newId in
                entries = entries.map { e in
                    e.exercise_id == target.id
                        ? Entry(entry_id: e.entry_id, set_number: e.set_number,
                                reps: e.reps, weight: e.weight,
                                session_id: e.session_id, exercise_id: newId)
                        : e
                }
                if let idx = exerciseOrder.firstIndex(of: target.id) {
                    exerciseOrder[idx] = newId
                }
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
            VStack(spacing: 2) {
                Text(session.name ?? session.dayOfWeek)
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                Text(session.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
            }
            Spacer()
            Button { showEditSession = true } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.2, green: 0.5, blue: 1.0),
                                     Color(red: 0.45, green: 0.2, blue: 0.95)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        in: Circle()
                    )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 14)
    }

    // MARK: - Stats row

    private var statsRow: some View {
        HStack(spacing: 10) {
            statBadge("\(exerciseOrder.count)", "Variations")
            statBadge("\(entries.count)", "Total Sets")
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "plus.circle.dashed")
                .font(.system(size: 50))
                .foregroundStyle(.white.opacity(0.15))
            Text("No exercises yet")
                .foregroundStyle(.white.opacity(0.35))
            Text("Tap + to add your first set")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.2))
            Spacer()
        }
    }

    // MARK: - Exercise list

    private var exerciseList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(Array(groupedEntries.enumerated()), id: \.element.id) { idx, group in
                    exerciseGroupCard(group: group, index: idx, total: groupedEntries.count)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - FAB

    private var addFAB: some View {
        Button { showAddExercise = true } label: {
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

    // MARK: - Exercise group card

    private func exerciseGroupCard(group: ExerciseGroup, index: Int, total: Int) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                // Name row + menu
                HStack {
                    Text(group.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Menu {
                        if index > 0 {
                            Button {
                                exerciseOrder.swapAt(index, index - 1)
                            } label: {
                                Label("Move Up", systemImage: "arrow.up")
                            }
                        }
                        if index < total - 1 {
                            Button {
                                exerciseOrder.swapAt(index, index + 1)
                            } label: {
                                Label("Move Down", systemImage: "arrow.down")
                            }
                        }
                        Divider()
                        Button {
                            replaceTarget = ReplaceTarget(id: group.exerciseId)
                        } label: {
                            Label("Replace Exercise", systemImage: "arrow.triangle.2.circlepath")
                        }
                        Divider()
                        Button(role: .destructive) {
                            Task {
                                try? await APIService.shared.deleteEntriesByExercise(
                                    sessionId: session.session_id,
                                    exerciseId: group.exerciseId
                                )
                                entries.removeAll { $0.exercise_id == group.exerciseId }
                                exerciseOrder.removeAll { $0 == group.exerciseId }
                            }
                        } label: {
                            Label("Delete Exercise", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(8)
                            .background(.white.opacity(0.07), in: Circle())
                    }
                }

                Divider().background(.white.opacity(0.1))

                // Column headers
                HStack {
                    Text("Set").frame(width: 36, alignment: .leading)
                    Text("Reps").frame(maxWidth: .infinity, alignment: .center)
                    Text("Weight").frame(maxWidth: .infinity, alignment: .trailing)
                    Color.clear.frame(width: 32)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.4))

                // Set rows
                ForEach(group.entries) { entry in
                    HStack {
                        Text("\(entry.set_number)")
                            .frame(width: 36, alignment: .leading)
                            .foregroundStyle(Color(red: 0.4, green: 0.7, blue: 1.0))
                            .fontWeight(.bold)
                        Text("\(entry.reps) reps")
                            .frame(maxWidth: .infinity, alignment: .center)
                        Text("\(entry.weight, specifier: "%.1f") kg")
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        Button {
                            deleteSet(entry: entry)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                                .foregroundStyle(Color(red: 1, green: 0.35, blue: 0.35).opacity(0.7))
                                .frame(width: 32, height: 32)
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                }

                // Add Set button
                Button {
                    addSetTarget = exercises.first { $0.exercise_id == group.exerciseId }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill").font(.system(size: 13))
                        Text("Add Set").font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Color(red: 0.4, green: 0.7, blue: 1.0))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        Color(red: 0.4, green: 0.7, blue: 1.0).opacity(0.1),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                }
            }
        }
    }

    // MARK: - Delete set with renumbering

    private func deleteSet(entry: Entry) {
        let exerciseId = entry.exercise_id
        let deletedSetNum = entry.set_number

        Task {
            try? await APIService.shared.deleteEntry(id: entry.entry_id)

            // Remove from local state
            entries.removeAll { $0.entry_id == entry.entry_id }
            if !entries.contains(where: { $0.exercise_id == exerciseId }) {
                exerciseOrder.removeAll { $0 == exerciseId }
                return
            }

            // Renumber remaining sets for this exercise
            let remaining = entries
                .filter { $0.exercise_id == exerciseId }
                .sorted { $0.set_number < $1.set_number }

            for (i, e) in remaining.enumerated() {
                let newNum = i + 1
                guard e.set_number != newNum else { continue }
                // Only renumber entries that were after the deleted set
                guard e.set_number > deletedSetNum else { continue }

                // Update local state
                if let idx = entries.firstIndex(where: { $0.entry_id == e.entry_id }) {
                    entries[idx] = Entry(
                        entry_id: e.entry_id, set_number: newNum,
                        reps: e.reps, weight: e.weight,
                        session_id: e.session_id, exercise_id: e.exercise_id
                    )
                }
                // Persist to DB
                Task { try? await APIService.shared.updateEntrySetNumber(id: e.entry_id, setNumber: newNum) }
            }
        }
    }

    // MARK: - Data

    private var groupedEntries: [ExerciseGroup] {
        let exMap = Dictionary(uniqueKeysWithValues: exercises.map { ($0.exercise_id, $0.exercise_name) })
        return exerciseOrder.compactMap { exId in
            let exEntries = entries.filter { $0.exercise_id == exId }.sorted { $0.set_number < $1.set_number }
            guard !exEntries.isEmpty else { return nil }
            return ExerciseGroup(exerciseId: exId, name: exMap[exId] ?? "Unknown", entries: exEntries)
        }
    }

    private func nextSetNumber(for exerciseId: Int) -> Int {
        (entries.filter { $0.exercise_id == exerciseId }.map(\.set_number).max() ?? 0) + 1
    }

    private func loadData() async {
        isLoading = true
        async let e  = APIService.shared.getEntries(sessionId: session.session_id)
        async let ex = APIService.shared.getExercises()
        let loaded = (try? await e) ?? []
        exercises  = (try? await ex) ?? []
        entries    = loaded
        var seen = Set<Int>(); var order: [Int] = []
        for entry in loaded where !seen.contains(entry.exercise_id) {
            seen.insert(entry.exercise_id); order.append(entry.exercise_id)
        }
        exerciseOrder = order
        isLoading = false
    }

    // MARK: - Helpers

    private func statBadge(_ value: String, _ label: String) -> some View {
        GlassCard(padding: 10) {
            VStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Supporting types

private struct ExerciseGroup: Identifiable {
    var id: Int { exerciseId }
    let exerciseId: Int
    let name: String
    let entries: [Entry]
}

private struct ReplaceTarget: Identifiable {
    let id: Int // exercise_id
}

// MARK: - Edit Session Sheet

struct EditSessionSheet: View {
    let session: WorkoutSession
    let onSave: (WorkoutSession) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var nameText: String
    @State private var selectedDate: Date
    @State private var notesText: String
    @State private var isLoading = false
    @State private var errorMessage: String?

    private static let df: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    init(session: WorkoutSession, onSave: @escaping (WorkoutSession) -> Void) {
        self.session = session
        self.onSave = onSave
        _nameText     = State(initialValue: session.name ?? "")
        _selectedDate = State(initialValue: Self.df.date(from: session.date) ?? Date())
        _notesText    = State(initialValue: session.notes ?? "")
    }

    var body: some View {
        VStack(spacing: 20) {
            RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.3))
                .frame(width: 36, height: 4).padding(.top, 12)

            Text("Edit Session").font(.title2.bold()).foregroundStyle(.white)

            GlassCard {
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "tag")
                            .foregroundStyle(.white.opacity(0.45)).frame(width: 20)
                        TextField("Session name", text: $nameText)
                            .foregroundStyle(.white)
                    }
                    Divider().background(.white.opacity(0.08))
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(.white.opacity(0.45)).frame(width: 20)
                        Text("Date").font(.subheadline).foregroundStyle(.white.opacity(0.6))
                        Spacer()
                        DatePicker("", selection: $selectedDate, displayedComponents: .date)
                            .datePickerStyle(.compact).labelsHidden().colorScheme(.dark)
                    }
                    Divider().background(.white.opacity(0.08))
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "note.text")
                            .foregroundStyle(.white.opacity(0.45)).frame(width: 20).padding(.top, 2)
                        TextField("Notes (optional)", text: $notesText, axis: .vertical)
                            .lineLimit(2...5).foregroundStyle(.white)
                    }
                }
            }
            .padding(.horizontal, 20)

            if let err = errorMessage {
                Text(err).font(.caption)
                    .foregroundStyle(Color(red: 1, green: 0.4, blue: 0.4))
            }

            GlassButton(isLoading ? "Saving..." : "Save Changes", icon: "checkmark.circle.fill") {
                let dateStr = Self.df.string(from: selectedDate)
                isLoading = true
                Task {
                    do {
                        let updated = try await APIService.shared.updateSession(
                            id: session.session_id, date: dateStr,
                            notes: notesText.isEmpty ? nil : notesText,
                            name: nameText.isEmpty ? nil : nameText
                        )
                        onSave(updated)
                        dismiss()
                    } catch { errorMessage = error.localizedDescription }
                    isLoading = false
                }
            }
            .disabled(isLoading)
            .padding(.horizontal, 20)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background { AnimatedBackground() }
        .colorScheme(.dark)
    }
}

// MARK: - Add Entry Sheet (two-level: muscle group → exercise)

struct AddEntrySheet: View {
    let session: WorkoutSession
    let exercises: [Exercise]
    let currentEntries: [Entry]
    let onAdd: (Entry) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedGroup: MuscleGroup? = nil
    @State private var selectedExercise: Exercise? = nil
    @State private var reps = ""
    @State private var weight = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private func nextSetNumber(for exerciseId: Int) -> Int {
        (currentEntries.filter { $0.exercise_id == exerciseId }.map(\.set_number).max() ?? 0) + 1
    }

    private func exercisesIn(_ group: MuscleGroup) -> [Exercise] {
        exercises.filter { muscleGroup(for: $0) == group }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Pull handle
            RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.3))
                .frame(width: 36, height: 4).padding(.top, 12).padding(.bottom, 16)

            // Header row
            HStack {
                if selectedGroup != nil {
                    Button {
                        selectedGroup = nil
                        selectedExercise = nil
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Groups")
                                .font(.subheadline.weight(.medium))
                        }
                        .foregroundStyle(Color(red: 0.4, green: 0.7, blue: 1.0))
                    }
                } else {
                    Color.clear.frame(width: 70)
                }
                Spacer()
                Text(selectedGroup == nil ? "Add Exercise" : selectedGroup!.rawValue)
                    .font(.title2.bold()).foregroundStyle(.white)
                Spacer()
                Color.clear.frame(width: 70)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            if let exercise = selectedExercise {
                // Phase 3: reps/weight form
                exerciseForm(exercise: exercise)
            } else if let group = selectedGroup {
                // Phase 2: exercises in group
                exerciseList(for: group)
            } else {
                // Phase 1: muscle group list
                muscleGroupList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background { AnimatedBackground() }
        .colorScheme(.dark)
    }

    // MARK: - Phase 1: Muscle group list

    private var muscleGroupList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(MuscleGroup.allCases, id: \.self) { group in
                    let groupExs = exercisesIn(group)
                    if !groupExs.isEmpty {
                        Button { selectedGroup = group } label: {
                            GlassCard(padding: 14) {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(group.color.opacity(0.15))
                                        .frame(width: 38, height: 38)
                                        .overlay(
                                            Image(systemName: "dumbbell")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(group.color)
                                        )
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(group.rawValue)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(.white)
                                        Text("\(groupExs.count) exercise\(groupExs.count == 1 ? "" : "s")")
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.45))
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.3))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Phase 2: Exercise list for a group

    private func exerciseList(for group: MuscleGroup) -> some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(exercisesIn(group)) { ex in
                    Button { selectedExercise = ex } label: {
                        GlassCard(padding: 14) {
                            HStack {
                                Text(ex.exercise_name)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.white)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.25))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Phase 3: Reps/weight form

    private func exerciseForm(exercise: Exercise) -> some View {
        VStack(spacing: 16) {
            // Selected exercise badge
            GlassCard(padding: 14) {
                HStack(spacing: 12) {
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
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Button { selectedExercise = nil } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
            }
            .padding(.horizontal, 20)

            GlassCard {
                HStack(spacing: 10) {
                    numField("Reps", text: $reps)
                    numField("Weight (kg)", text: $weight)
                }
            }
            .padding(.horizontal, 20)

            if let err = errorMessage {
                Text(err).font(.caption)
                    .foregroundStyle(Color(red: 1, green: 0.4, blue: 0.4))
            }

            GlassButton("Add Set", icon: "plus.circle.fill") {
                guard let repsN = Int(reps), let weightD = Double(weight) else {
                    errorMessage = "Fill in all fields correctly."; return
                }
                let setN = nextSetNumber(for: exercise.exercise_id)
                isLoading = true
                Task {
                    do {
                        let entry = try await APIService.shared.createEntry(
                            setNumber: setN, reps: repsN, weight: weightD,
                            sessionId: session.session_id, exerciseId: exercise.exercise_id
                        )
                        onAdd(entry); dismiss()
                    } catch { errorMessage = error.localizedDescription }
                    isLoading = false
                }
            }
            .disabled(isLoading)
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    private func numField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(.decimalPad).foregroundStyle(.white).multilineTextAlignment(.center)
            .padding(12)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Add Set Sheet (inline, exercise pre-selected)

struct AddSetSheet: View {
    let session: WorkoutSession
    let exercise: Exercise
    let setNumber: Int
    let onAdd: (Entry) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var reps = ""
    @State private var weight = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.3))
                .frame(width: 36, height: 4).padding(.top, 12)

            VStack(spacing: 4) {
                Text("Set \(setNumber)").font(.title2.bold()).foregroundStyle(.white)
                Text(exercise.exercise_name).font(.subheadline).foregroundStyle(.white.opacity(0.5))
            }

            GlassCard {
                HStack(spacing: 10) {
                    numField("Reps", text: $reps)
                    numField("Weight (kg)", text: $weight)
                }
            }
            .padding(.horizontal, 20)

            if let err = errorMessage {
                Text(err).font(.caption)
                    .foregroundStyle(Color(red: 1, green: 0.4, blue: 0.4))
            }

            GlassButton("Add Set \(setNumber)", icon: "plus.circle.fill") {
                guard let repsN = Int(reps), let weightD = Double(weight) else {
                    errorMessage = "Fill in all fields correctly."; return
                }
                isLoading = true
                Task {
                    do {
                        let entry = try await APIService.shared.createEntry(
                            setNumber: setNumber, reps: repsN, weight: weightD,
                            sessionId: session.session_id, exerciseId: exercise.exercise_id
                        )
                        onAdd(entry); dismiss()
                    } catch { errorMessage = error.localizedDescription }
                    isLoading = false
                }
            }
            .disabled(isLoading)
            .padding(.horizontal, 20)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background { AnimatedBackground() }
        .colorScheme(.dark)
    }

    private func numField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(.decimalPad).foregroundStyle(.white).multilineTextAlignment(.center)
            .padding(12)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Replace Exercise Sheet

struct ReplaceExerciseSheet: View {
    let session: WorkoutSession
    let exercises: [Exercise]
    let currentExerciseId: Int
    let onReplace: (Int) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var filtered: [Exercise] {
        let others = exercises.filter { $0.exercise_id != currentExerciseId }
        guard !searchText.isEmpty else { return others }
        return others.filter { $0.exercise_name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.3))
                .frame(width: 36, height: 4).padding(.top, 12).padding(.bottom, 16)

            Text("Replace Exercise").font(.title2.bold()).foregroundStyle(.white).padding(.bottom, 16)

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
            .padding(.horizontal, 20).padding(.bottom, 12)

            if let err = errorMessage {
                Text(err).font(.caption)
                    .foregroundStyle(Color(red: 1, green: 0.4, blue: 0.4))
                    .padding(.horizontal, 20).padding(.bottom, 8)
            }

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filtered) { ex in
                        Button {
                            isLoading = true
                            Task {
                                do {
                                    try await APIService.shared.replaceExercise(
                                        sessionId: session.session_id,
                                        oldExerciseId: currentExerciseId,
                                        newExerciseId: ex.exercise_id
                                    )
                                    onReplace(ex.exercise_id)
                                    dismiss()
                                } catch {
                                    errorMessage = error.localizedDescription
                                    isLoading = false
                                }
                            }
                        } label: {
                            GlassCard(padding: 14) {
                                HStack(spacing: 14) {
                                    Image(systemName: "figure.strengthtraining.traditional")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color(red: 0.4, green: 0.7, blue: 1.0))
                                        .frame(width: 32, height: 32)
                                        .background(.white.opacity(0.08), in: Circle())
                                    Text(ex.exercise_name)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    if isLoading {
                                        ProgressView().tint(.white).scaleEffect(0.7)
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isLoading)
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background { AnimatedBackground() }
        .colorScheme(.dark)
    }
}
