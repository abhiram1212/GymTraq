import SwiftUI
import UIKit

// MARK: - Session Detail

struct SessionDetailView: View {
    @State private var session: WorkoutSession
    var onUpdate: ((WorkoutSession) -> Void)?
    // Cross-session history from the sessions list — powers "last time" hints
    // and personal-record detection without extra fetches
    let historySessions: [WorkoutSession]
    let historyEntries: [Entry]
    @State private var entries: [Entry] = []
    @State private var exercises: [Exercise] = []
    @State private var exerciseOrder: [Int] = []
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var actionError: String?
    @State private var prBanner: String?
    @State private var restRemaining: Int?
    @State private var restTask: Task<Void, Never>?
    @State private var showEditSession = false
    @State private var showAddExercise = false
    @State private var showPlan = false
    @State private var planAutoShown = false
    @State private var addSetTarget: Exercise?
    @State private var replaceTarget: ReplaceTarget?
    @Environment(\.dismiss) private var dismiss

    init(session: WorkoutSession,
         historySessions: [WorkoutSession] = [],
         historyEntries: [Entry] = [],
         onUpdate: ((WorkoutSession) -> Void)? = nil) {
        _session = State(initialValue: session)
        self.historySessions = historySessions
        self.historyEntries = historyEntries
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

            if let err = actionError {
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
                    try? await Task.sleep(for: .seconds(4))
                    actionError = nil
                }
            }

            if isLoading {
                Spacer()
                ProgressView().tint(.white)
                Spacer()
            } else if let err = loadError {
                errorState(err)
            } else if exerciseOrder.isEmpty {
                emptyState
            } else {
                exerciseList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .bottomTrailing) {
            if loadError == nil {
                addFAB
                    .padding(.trailing, 24)
                    .padding(.bottom, 16)
            }
        }
        .overlay(alignment: .top) {
            if let pr = prBanner {
                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill").foregroundStyle(.black)
                    Text(pr)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.appAccent, in: Capsule())
                .shadow(color: Color.appAccent.opacity(0.4), radius: 12, y: 4)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .task(id: pr) {
                    try? await Task.sleep(for: .seconds(3.5))
                    withAnimation(.spring(duration: 0.4)) { prBanner = nil }
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let remaining = restRemaining {
                restBar(remaining)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
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
            AddEntrySheet(session: session, exercises: exercises, currentEntries: entries,
                          lastPerformance: { lastPerformance(for: $0) }) { newEntry in
                registerNewEntry(newEntry)
                if !exerciseOrder.contains(newEntry.exercise_id) {
                    exerciseOrder.append(newEntry.exercise_id)
                }
            }
        }
        .sheet(item: $addSetTarget) { exercise in
            AddSetSheet(
                session: session,
                exercise: exercise,
                setNumber: nextSetNumber(for: exercise.exercise_id),
                lastPerformance: lastPerformance(for: exercise.exercise_id)
            ) { newEntry in
                registerNewEntry(newEntry)
            }
        }
        .sheet(item: $replaceTarget) { target in
            ReplaceExerciseSheet(
                session: session,
                exercises: exercises,
                currentExerciseId: target.id
            ) { _ in
                // The server may merge the sets into an existing group and renumber
                // them — reload rather than guessing the result locally
                Task { await loadData() }
            }
        }
        .sheet(isPresented: $showPlan) {
            SessionPlanSheet(
                exercises: exercises,
                historySessions: historySessions,
                historyEntries: historyEntries,
                currentSessionId: session.session_id,
                log: logPlanned
            )
            .presentationDetents([.large, .medium])  // drag down to minimize/dismiss
            .presentationDragIndicator(.visible)
        }
        .colorScheme(.dark)
    }

    // Log a planned set: parent owns set numbering + PR/rest-timer side effects
    private func logPlanned(exercise: Exercise, reps: Int, weight: Double) async -> Bool {
        let setN = nextSetNumber(for: exercise.exercise_id)
        do {
            let entry = try await APIService.shared.createEntry(
                setNumber: setN, reps: reps, weight: weight,
                sessionId: session.session_id, exerciseId: exercise.exercise_id
            )
            if !exerciseOrder.contains(entry.exercise_id) { exerciseOrder.append(entry.exercise_id) }
            registerNewEntry(entry)
            return true
        } catch {
            actionError = error.localizedDescription
            return false
        }
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
            HStack(spacing: 8) {
                // Reopen the target/plan sheet anytime (history + progressive targets)
                Button { showPlan = true } label: {
                    Image(systemName: "target")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(Color.appCardElevated, in: Circle())
                }
                Button { showEditSession = true } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(10)
                        .background(
                            LinearGradient(
                                colors: [Color.appAccent,
                                         Color.appAccentDeep],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            in: Circle()
                        )
                }
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

    // MARK: - Error state

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.2))
            Text("Couldn't load this session")
                .foregroundStyle(.white.opacity(0.5))
            Text(message)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.3))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button {
                Task { await loadData() }
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
                            .foregroundStyle(Color.appAccent)
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
                                .foregroundStyle(Color.appDanger.opacity(0.7))
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
                    .foregroundStyle(Color.appAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        Color.appAccent.opacity(0.1),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                }
            }
        }
    }

    // MARK: - New entry: PR detection + rest timer

    private func registerNewEntry(_ newEntry: Entry) {
        // PR = beats every previous set for this exercise. Requires prior data,
        // so a brand-new exercise's first set isn't a hollow "PR".
        let priorMax = (historyEntries.filter { $0.exercise_id == newEntry.exercise_id && $0.session_id != session.session_id }
                        + entries.filter { $0.exercise_id == newEntry.exercise_id })
            .map(\.weight).max()
        entries.append(newEntry)

        if let priorMax, newEntry.weight > priorMax {
            let name = exercises.first { $0.exercise_id == newEntry.exercise_id }?.exercise_name ?? "Exercise"
            withAnimation(.spring(duration: 0.4)) {
                prBanner = "New PR — \(name) \(formatWeight(newEntry.weight)) kg!"
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }

        startRest()
    }

    // MARK: - "Last time" hint

    /// Summary of the most recent earlier session containing this exercise,
    /// e.g. "3 sets · top 60 kg × 8 · Jul 15".
    private func lastPerformance(for exerciseId: Int) -> String? {
        let grouped = Dictionary(
            grouping: historyEntries.filter { $0.exercise_id == exerciseId && $0.session_id != session.session_id },
            by: \.session_id
        )
        let dated: [(date: String, sets: [Entry])] = grouped.compactMap { sid, sets in
            guard let s = historySessions.first(where: { $0.session_id == sid }),
                  s.date <= session.date else { return nil }
            return (s.date, sets)
        }.sorted { $0.date > $1.date }

        guard let last = dated.first,
              let top = last.sets.max(by: { $0.weight < $1.weight }) else { return nil }
        let when = historySessions.first { $0.date == last.date }?.formattedDate ?? last.date
        return "\(last.sets.count) set\(last.sets.count == 1 ? "" : "s") · top \(formatWeight(top.weight)) kg × \(top.reps) · \(when)"
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", w) : String(format: "%.1f", w)
    }

    // MARK: - Rest timer

    private func startRest(_ seconds: Int = 90) {
        restTask?.cancel()
        withAnimation(.spring(duration: 0.35)) { restRemaining = seconds }
        restTask = Task {
            while let r = restRemaining, r > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                restRemaining = r - 1
            }
            guard !Task.isCancelled else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            try? await Task.sleep(for: .seconds(2))
            if !Task.isCancelled {
                withAnimation(.spring(duration: 0.35)) { restRemaining = nil }
            }
        }
    }

    private func restBar(_ remaining: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "timer")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(remaining == 0 ? Color.appAccent : .white.opacity(0.7))
            Text(remaining == 0 ? "Rest done — go!" : String(format: "Rest %d:%02d", remaining / 60, remaining % 60))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText(countsDown: true))
                .animation(.snappy, value: remaining)

            if remaining > 0 {
                Button {
                    restRemaining = remaining + 30
                } label: {
                    Text("+30s")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.appAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.appAccent.opacity(0.15), in: Capsule())
                }
            }

            Button {
                restTask?.cancel()
                withAnimation(.spring(duration: 0.35)) { restRemaining = nil }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(6)
                    .background(.white.opacity(0.1), in: Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.appCardElevated, in: Capsule())
        .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
    }

    // MARK: - Delete set

    // The server deletes and renumbers the exercise's sets in one transaction;
    // here we just mirror that result locally — and only after the call succeeds.
    private func deleteSet(entry: Entry) {
        let exerciseId = entry.exercise_id
        Task {
            do {
                try await APIService.shared.deleteEntry(id: entry.entry_id)
            } catch {
                actionError = error.localizedDescription
                return
            }

            entries.removeAll { $0.entry_id == entry.entry_id }
            if !entries.contains(where: { $0.exercise_id == exerciseId }) {
                exerciseOrder.removeAll { $0 == exerciseId }
                return
            }

            // Mirror the server's 1..n renumbering
            let remaining = entries
                .filter { $0.exercise_id == exerciseId }
                .sorted { $0.set_number < $1.set_number }
            for (i, e) in remaining.enumerated() where e.set_number != i + 1 {
                if let idx = entries.firstIndex(where: { $0.entry_id == e.entry_id }) {
                    entries[idx] = Entry(
                        entry_id: e.entry_id, set_number: i + 1,
                        reps: e.reps, weight: e.weight,
                        session_id: e.session_id, exercise_id: e.exercise_id
                    )
                }
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
        loadError = nil
        do {
            // Entries are per-session and fetched fresh; the exercise catalog
            // comes from the shared cache (usually already in memory)
            async let e = APIService.shared.getEntries(sessionId: session.session_id)
            await ExerciseStore.shared.loadIfNeeded()
            exercises  = ExerciseStore.shared.exercises
            let loaded = try await e
            entries    = loaded
            var seen = Set<Int>(); var order: [Int] = []
            for entry in loaded where !seen.contains(entry.exercise_id) {
                seen.insert(entry.exercise_id); order.append(entry.exercise_id)
            }
            exerciseOrder = order

            // New/empty session → offer the plan once (progressive-overload targets).
            // Only if there's history to suggest from; otherwise it'd be an empty prompt.
            if entries.isEmpty && !planAutoShown {
                planAutoShown = true
                let hasHistory = historyEntries.contains { $0.session_id != session.session_id }
                if hasHistory { showPlan = true }
            }
        } catch {
            // Don't render a fake "No exercises yet" over a network failure
            loadError = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Helpers

    private func statBadge(_ value: String, _ label: String) -> some View {
        GlassCard(padding: 10) {
            VStack(spacing: 2) {
                // Numbers roll like Apple's activity counters when sets change
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: value)
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
                        DatePicker("", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
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
                    .foregroundStyle(Color.appDanger)
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
    var lastPerformance: (Int) -> String? = { _ in nil }
    let onAdd: (Entry) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedGroup: MuscleGroup? = nil
    @State private var selectedExercise: Exercise? = nil
    @State private var searchText = ""
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
                        .foregroundStyle(Color.appAccent)
                    }
                } else {
                    Color.clear.frame(width: 70)
                }
                Spacer()
                // Search results span all groups — don't title them with one group's name
                Text(!searchText.isEmpty && selectedExercise == nil
                     ? "Add Exercise"
                     : (selectedGroup == nil ? "Add Exercise" : selectedGroup!.rawValue))
                    .font(.title2.bold()).foregroundStyle(.white)
                Spacer()
                Color.clear.frame(width: 70)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            if let exercise = selectedExercise {
                // Phase 3: reps/weight form
                exerciseForm(exercise: exercise)
            } else if exercises.isEmpty {
                // Nothing in the catalog — say so instead of showing a blank screen
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "dumbbell")
                        .font(.system(size: 44))
                        .foregroundStyle(.white.opacity(0.15))
                    Text("No exercises in your library")
                        .foregroundStyle(.white.opacity(0.4))
                    Text("Add exercises from the Exercises tab first")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.25))
                    Spacer()
                }
            } else {
                searchBar

                if !searchText.isEmpty {
                    // Search cuts across all groups
                    searchResults
                } else if let group = selectedGroup {
                    // Phase 2: exercises in group
                    exerciseList(for: group)
                } else {
                    // Phase 1: muscle group list
                    muscleGroupList
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background { AnimatedBackground() }
        .keyboardDoneButton()
        .colorScheme(.dark)
    }

    // MARK: - Search

    private var searchBar: some View {
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
    }

    private var searchResults: some View {
        let matches = exercises.filter {
            $0.exercise_name.localizedCaseInsensitiveContains(searchText)
        }
        return ScrollView {
            LazyVStack(spacing: 8) {
                if matches.isEmpty {
                    Text("No matches")
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.top, 24)
                }
                ForEach(matches) { ex in
                    Button { selectedExercise = ex } label: {
                        GlassCard(padding: 14) {
                            HStack(spacing: 12) {
                                let group = muscleGroup(for: ex)
                                Circle()
                                    .fill(group.color.opacity(0.15))
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Image(systemName: "dumbbell")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(group.color)
                                    )
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

    // MARK: - Phase 1: Muscle group list

    private var muscleGroupList: some View {
        // One classification pass for the whole catalog, not one per group
        let grouped = Dictionary(grouping: exercises) { muscleGroup(for: $0) }
        return ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(MuscleGroup.allCases, id: \.self) { group in
                    let groupExs = grouped[group] ?? []
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

            // What you did last time — the number you actually came here for
            if let hint = lastPerformance(exercise.exercise_id) {
                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.appAccent)
                    Text("Last time: \(hint)")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                }
                .padding(12)
                .background(Color.appAccent.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 20)
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
                    .foregroundStyle(Color.appDanger)
            }

            GlassButton(isLoading ? "Adding..." : "Add Set", icon: "plus.circle.fill") {
                guard let repsN = Int(reps), let weightD = parseDecimal(weight) else {
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
    var lastPerformance: String? = nil
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

            if let hint = lastPerformance {
                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.appAccent)
                    Text("Last time: \(hint)")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                }
                .padding(12)
                .background(Color.appAccent.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 20)
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
                    .foregroundStyle(Color.appDanger)
            }

            GlassButton(isLoading ? "Adding..." : "Add Set \(setNumber)", icon: "plus.circle.fill") {
                guard let repsN = Int(reps), let weightD = parseDecimal(weight) else {
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
        .keyboardDoneButton()
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
            .background(Color.appCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.white.opacity(0.1), lineWidth: 1))
            .padding(.horizontal, 20).padding(.bottom, 12)

            if let err = errorMessage {
                Text(err).font(.caption)
                    .foregroundStyle(Color.appDanger)
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
                                        .foregroundStyle(Color.appAccent)
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
