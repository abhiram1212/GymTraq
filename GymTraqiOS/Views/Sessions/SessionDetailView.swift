import SwiftUI

struct SessionDetailView: View {
    let session: WorkoutSession
    @State private var entries: [Entry] = []
    @State private var exercises: [Exercise] = []
    @State private var isLoading = false
    @State private var showAdd = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AnimatedBackground()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(10)
                            .background(.white.opacity(0.1), in: Circle())
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Text(session.dayOfWeek)
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                        Text(session.formattedDate)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    Spacer()
                    Button { showAdd = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
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
                .padding(.bottom, 16)

                if let notes = session.notes, !notes.isEmpty {
                    GlassCard(padding: 12) {
                        HStack {
                            Image(systemName: "note.text")
                                .foregroundStyle(.white.opacity(0.4))
                            Text(notes)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                }

                // Stats row
                if !entries.isEmpty {
                    HStack(spacing: 12) {
                        statBadge(value: "\(entries.count)", label: "Sets")
                        statBadge(value: "\(entries.map(\.reps).reduce(0, +))", label: "Total Reps")
                        statBadge(value: "\(Int(entries.map(\.weight).max() ?? 0)) kg", label: "Max Weight")
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                }

                if isLoading {
                    Spacer()
                    ProgressView().tint(.white)
                    Spacer()
                } else if entries.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "plus.circle.dashed")
                            .font(.system(size: 50))
                            .foregroundStyle(.white.opacity(0.15))
                        Text("No entries yet")
                            .foregroundStyle(.white.opacity(0.35))
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(groupedEntries, id: \.key) { exerciseName, entryGroup in
                                exerciseGroup(name: exerciseName, entries: entryGroup)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .task {
            isLoading = true
            async let e = APIService.shared.getEntries(sessionId: session.session_id)
            async let ex = APIService.shared.getExercises()
            entries = (try? await e) ?? []
            exercises = (try? await ex) ?? []
            isLoading = false
        }
        .sheet(isPresented: $showAdd) {
            AddEntrySheet(session: session, exercises: exercises) { newEntry in
                entries.append(newEntry)
                entries.sort { $0.set_number < $1.set_number }
            }
        }
        .colorScheme(.dark)
    }

    private var groupedEntries: [(key: String, value: [Entry])] {
        let exMap = Dictionary(uniqueKeysWithValues: exercises.map { ($0.exercise_id, $0.exercise_name) })
        let grouped = Dictionary(grouping: entries) { exMap[$0.exercise_id] ?? "Unknown" }
        return grouped.sorted { $0.key < $1.key }
    }

    private func exerciseGroup(name: String, entries: [Entry]) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)

                Divider().background(.white.opacity(0.1))

                HStack {
                    Text("Set").frame(width: 36, alignment: .leading)
                    Text("Reps").frame(maxWidth: .infinity, alignment: .center)
                    Text("Weight").frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.4))

                ForEach(entries) { entry in
                    HStack {
                        Text("\(entry.set_number)")
                            .frame(width: 36, alignment: .leading)
                            .foregroundStyle(Color(red: 0.4, green: 0.7, blue: 1.0))
                            .fontWeight(.bold)
                        Text("\(entry.reps) reps")
                            .frame(maxWidth: .infinity, alignment: .center)
                        Text("\(entry.weight, specifier: "%.1f") kg")
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
    }

    private func statBadge(value: String, label: String) -> some View {
        GlassCard(padding: 12) {
            VStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct AddEntrySheet: View {
    let session: WorkoutSession
    let exercises: [Exercise]
    let onAdd: (Entry) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedExercise: Exercise?
    @State private var setNumber = ""
    @State private var reps = ""
    @State private var weight = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            AnimatedBackground()
            VStack(spacing: 20) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(.white.opacity(0.3))
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)

                Text("Add Set")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                GlassCard {
                    VStack(spacing: 14) {
                        // Exercise picker
                        Menu {
                            ForEach(exercises) { ex in
                                Button(ex.exercise_name) { selectedExercise = ex }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "figure.strengthtraining.traditional")
                                    .foregroundStyle(.white.opacity(0.5))
                                Text(selectedExercise?.exercise_name ?? "Select Exercise")
                                    .foregroundStyle(selectedExercise == nil ? .white.opacity(0.4) : .white)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                            .padding(14)
                            .background(.white.opacity(0.08),
                                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        HStack(spacing: 10) {
                            numField("Set #", text: $setNumber)
                            numField("Reps", text: $reps)
                            numField("Weight (kg)", text: $weight)
                        }

                        if let err = errorMessage {
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(Color(red: 1, green: 0.4, blue: 0.4))
                        }
                    }
                }
                .padding(.horizontal, 20)

                GlassButton("Add Set", icon: "plus.circle.fill") {
                    guard let ex = selectedExercise,
                          let setN = Int(setNumber),
                          let repsN = Int(reps),
                          let weightD = Double(weight) else {
                        errorMessage = "Fill in all fields correctly."
                        return
                    }
                    isLoading = true
                    Task {
                        do {
                            let entry = try await APIService.shared.createEntry(
                                setNumber: setN, reps: repsN, weight: weightD,
                                sessionId: session.session_id, exerciseId: ex.exercise_id
                            )
                            onAdd(entry)
                            dismiss()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                        isLoading = false
                    }
                }
                .padding(.horizontal, 20)
                .disabled(isLoading)

                Spacer()
            }
        }
        .colorScheme(.dark)
    }

    private func numField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(.decimalPad)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(12)
            .background(.white.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .frame(maxWidth: .infinity)
    }
}
