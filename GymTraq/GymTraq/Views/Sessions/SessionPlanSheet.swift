import SwiftUI

// Progressive-overload target from the last top set.
// Double progression: cap reps, then bump weight and reset reps.
func progressiveTarget(weight: Double, reps: Int) -> (weight: Double, reps: Int) {
    reps >= 10 ? (weight + 2.5, 8) : (weight, reps + 1)
}

private struct ExerciseSuggestion: Identifiable {
    let exercise: Exercise
    let lastWeight: Double
    let lastReps: Int
    let lastDate: String        // "yyyy-MM-dd"
    let lastDateLabel: String   // "Jul 22"
    let targetWeight: Double
    let targetReps: Int
    var id: Int { exercise.exercise_id }
}

/// "What are you training today?" → suggested targets per exercise from history.
struct SessionPlanSheet: View {
    let exercises: [Exercise]
    let historySessions: [WorkoutSession]
    let historyEntries: [Entry]
    let currentSessionId: Int
    /// Log a set for the session; returns success. Parent handles set numbering, PR, rest timer.
    let log: (Exercise, Int, Double) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var selectedGroup: MuscleGroup?
    @State private var repsInput: [Int: String] = [:]
    @State private var weightInput: [Int: String] = [:]
    @State private var loggedCount: [Int: Int] = [:]
    @State private var busyId: Int?

    private static let out: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f
    }()
    private static let ymd: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    var body: some View {
        // A real navigation bar: title + back stay PINNED, while the scroll view
        // fills the whole sheet and content passes *underneath* the bar (iOS 26's
        // scroll-edge blur keeps it legible). Beats both a sibling-below-header
        // layout (content boxed in) and an all-in-one scroll (nav scrolls away).
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let group = selectedGroup {
                        planContent(for: group)
                    } else {
                        groupPicker
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background { AnimatedBackground() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Custom principal title keeps SF Rounded, matching the app's display type
                ToolbarItem(placement: .principal) {
                    Text(selectedGroup?.rawValue ?? "Today's Plan")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                if selectedGroup != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            withAnimation(.spring(duration: 0.25)) { selectedGroup = nil }
                        } label: {
                            Label("Groups", systemImage: "chevron.left")
                                .font(.subheadline.weight(.medium))
                        }
                        .tint(Color.appAccent)
                    }
                } else {
                    // Always reachable, instead of buried under a long group grid
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Skip") { dismiss() }
                            .font(.subheadline.weight(.medium))
                            .tint(.white.opacity(0.5))
                    }
                }
            }
            .keyboardDoneButton()
        }
        .colorScheme(.dark)
    }

    // MARK: - Phase 1: pick focus

    private var groupPicker: some View {
        VStack(spacing: 16) {
            Text("What are you training today?")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))

            if availableGroups.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.badge.questionmark")
                        .font(.system(size: 36))
                        .foregroundStyle(.white.opacity(0.15))
                    Text("No workout history yet")
                        .foregroundStyle(.white.opacity(0.4))
                    Text("Log a few sessions and targets will appear here.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.25))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 30)
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                    GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(availableGroups, id: \.self) { group in
                        Button {
                            selectGroup(group)
                        } label: {
                            VStack(spacing: 8) {
                                Circle()
                                    .fill(group.color.opacity(0.15))
                                    .frame(width: 46, height: 46)
                                    .overlay(Image(systemName: "dumbbell")
                                        .foregroundStyle(group.color))
                                Text(group.rawValue)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color.appCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(PressableCardStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Phase 2: suggested targets

    private func planContent(for group: MuscleGroup) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.forward.circle.fill")
                    .foregroundStyle(Color.appAccent)
                Text("Targets nudge you past last time. Adjust if needed, then log.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
            }
            .padding(.horizontal, 20)

            ForEach(suggestions(for: group)) { s in
                suggestionRow(s)
            }
        }
    }

    private func suggestionRow(_ s: ExerciseSuggestion) -> some View {
        GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(s.exercise.exercise_name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    if let n = loggedCount[s.id], n > 0 {
                        Label("\(n) set\(n == 1 ? "" : "s")", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.appSuccess)
                    }
                }

                Text("Last: \(fmt(s.lastWeight)) kg × \(s.lastReps) · \(s.lastDateLabel)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))

                HStack(spacing: 8) {
                    field("Reps", value: repsBinding(s.id))
                    field("kg", value: weightBinding(s.id))

                    Button {
                        Task { await logRow(s) }
                    } label: {
                        Group {
                            if busyId == s.id {
                                ProgressView().tint(.black)
                            } else {
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .bold))
                            }
                        }
                        .foregroundStyle(.black)
                        .frame(width: 46, height: 42)
                        .background(Color.appAccent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(PressableCardStyle())
                    .disabled(busyId == s.id) // only this row waits, not the whole list
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func repsBinding(_ id: Int) -> Binding<String> {
        Binding(get: { repsInput[id] ?? "" }, set: { repsInput[id] = $0 })
    }
    private func weightBinding(_ id: Int) -> Binding<String> {
        Binding(get: { weightInput[id] ?? "" }, set: { weightInput[id] = $0 })
    }

    private func field(_ placeholder: String, value: Binding<String>) -> some View {
        TextField(placeholder, text: value)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(Color.appCardElevated, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Actions

    private func selectGroup(_ group: MuscleGroup) {
        // Prefill each exercise's inputs with its progressive target
        for s in suggestions(for: group) {
            repsInput[s.id] = "\(s.targetReps)"
            weightInput[s.id] = fmt(s.targetWeight)
        }
        withAnimation(.spring(duration: 0.25)) { selectedGroup = group }
    }

    private func logRow(_ s: ExerciseSuggestion) async {
        guard let reps = Int(repsInput[s.id] ?? ""),
              let weight = parseDecimal(weightInput[s.id] ?? "") else { return }
        busyId = s.id
        if await log(s.exercise, reps, weight) {
            loggedCount[s.id, default: 0] += 1
        }
        busyId = nil
    }

    // MARK: - Suggestion computation

    private var availableGroups: [MuscleGroup] {
        let priorExerciseIds = Set(historyEntries
            .filter { $0.session_id != currentSessionId }
            .map(\.exercise_id))
        let groups = exercises
            .filter { priorExerciseIds.contains($0.exercise_id) }
            .map { muscleGroup(for: $0) }
        return MuscleGroup.allCases.filter { groups.contains($0) }
    }

    private func suggestions(for group: MuscleGroup) -> [ExerciseSuggestion] {
        let groupExercises = exercises.filter { muscleGroup(for: $0) == group }
        let dateBySession = Dictionary(uniqueKeysWithValues: historySessions.map { ($0.session_id, $0.date) })

        return groupExercises.compactMap { ex -> ExerciseSuggestion? in
            // Most recent PAST session that trained this exercise
            let prior = historyEntries.filter {
                $0.exercise_id == ex.exercise_id && $0.session_id != currentSessionId
            }
            let bySession = Dictionary(grouping: prior, by: \.session_id)
            let dated = bySession.compactMap { sid, sets -> (date: String, sets: [Entry])? in
                guard let d = dateBySession[sid] else { return nil }
                return (d, sets)
            }.sorted { $0.date > $1.date }

            guard let last = dated.first,
                  let top = last.sets.max(by: { $0.weight < $1.weight }) else { return nil }

            let target = progressiveTarget(weight: top.weight, reps: top.reps)
            let label = Self.ymd.date(from: last.date).map { Self.out.string(from: $0) } ?? last.date
            return ExerciseSuggestion(
                exercise: ex, lastWeight: top.weight, lastReps: top.reps,
                lastDate: last.date, lastDateLabel: label,
                targetWeight: target.weight, targetReps: target.reps
            )
        }
        .sorted { $0.lastDate > $1.lastDate }
    }

    private func fmt(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", w) : String(format: "%.1f", w)
    }
}
