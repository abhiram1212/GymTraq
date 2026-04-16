import SwiftUI

struct SessionsView: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var vm = SessionsViewModel()
    @State private var showAdd = false
    @State private var showProfile = false
    @State private var selectedSession: WorkoutSession?
    @State private var sessionToDelete: WorkoutSession?

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 16)

            if vm.isLoading {
                Spacer()
                ProgressView().tint(.white)
                Spacer()
            } else if vm.sessions.isEmpty {
                emptyState
            } else {
                sessionList
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
        .confirmationDialog(
            "Delete this session?",
            isPresented: Binding(
                get: { sessionToDelete != nil },
                set: { if !$0 { sessionToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let s = sessionToDelete {
                Button("Delete Session", role: .destructive) {
                    Task { await vm.delete(session: s) }
                    sessionToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) { sessionToDelete = nil }
        } message: {
            Text("This will permanently delete the session and all its entries.")
        }
        .sheet(isPresented: $showAdd) {
            AddSessionSheet(vm: vm)
        }
        .sheet(item: $selectedSession) { session in
            SessionDetailView(session: session) { updated in
                vm.update(session: updated)
            }
        }
        .sheet(isPresented: $showProfile) {
            ProfileView()
        }
        .colorScheme(.dark)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Workouts")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("\(vm.sessions.count) sessions logged")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            Button { showProfile = true } label: {
                Image(systemName: "person.circle")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }

    // MARK: - Session list

    private var sessionList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(vm.sessions) { session in
                    SessionCard(session: session, summary: vm.exerciseSummary(for: session.session_id))
                        .onTapGesture { selectedSession = session }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                sessionToDelete = session
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "figure.run.circle")
                .font(.system(size: 60))
                .foregroundStyle(.white.opacity(0.15))
            Text("No sessions yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white.opacity(0.4))
            Text("Tap + to log your first workout")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.25))
            Spacer()
        }
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
                .shadow(color: Color(red: 0.3, green: 0.4, blue: 1.0).opacity(0.5),
                        radius: 16, y: 6)
        }
    }
}

// MARK: - Session Card

struct SessionCard: View {
    let session: WorkoutSession
    let summary: String

    var body: some View {
        GlassCard {
            HStack(spacing: 16) {
                VStack(spacing: 2) {
                    let parts = session.date.components(separatedBy: "-")
                    Text(parts.count == 3 ? monthAbbr(parts[1]) : "")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                        .textCase(.uppercase)
                    Text(parts.count == 3 ? parts[2] : "")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .frame(width: 44)
                .padding(10)
                .background(.white.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(session.name ?? session.dayOfWeek)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.25))
            }
        }
    }

    private func monthAbbr(_ m: String) -> String {
        let months = ["","Jan","Feb","Mar","Apr","May","Jun",
                      "Jul","Aug","Sep","Oct","Nov","Dec"]
        return months[Int(m) ?? 0]
    }
}

// MARK: - Add Session Sheet

struct AddSessionSheet: View {
    var vm: SessionsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var sessionName = ""
    @State private var date = Date()
    @State private var notes = ""
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 24) {
            RoundedRectangle(cornerRadius: 3)
                .fill(.white.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 12)

            Text("New Session")
                .font(.title2.bold())
                .foregroundStyle(.white)

            GlassCard {
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "tag")
                            .foregroundStyle(.white.opacity(0.45))
                            .frame(width: 20)
                        TextField(timeOfDayName(for: date), text: $sessionName)
                            .foregroundStyle(.white)
                    }

                    Divider().background(.white.opacity(0.1))

                    DatePicker("Date", selection: $date, displayedComponents: .date)
                        .foregroundStyle(.white)
                        .colorScheme(.dark)

                    Divider().background(.white.opacity(0.1))

                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .foregroundStyle(.white)
                        .lineLimit(3...5)
                }
            }
            .padding(.horizontal, 20)

            GlassButton("Log Session", icon: "checkmark.circle.fill") {
                isLoading = true
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                let trimmed = sessionName.trimmingCharacters(in: .whitespacesAndNewlines)
                let finalName = trimmed.isEmpty ? timeOfDayName(for: date) : trimmed
                Task {
                    await vm.create(
                        date: formatter.string(from: date),
                        notes: notes.isEmpty ? nil : notes,
                        name: finalName
                    )
                    dismiss()
                }
            }
            .padding(.horizontal, 20)
            .disabled(isLoading)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background { AnimatedBackground() }
        .colorScheme(.dark)
    }

    private func timeOfDayName(for date: Date) -> String {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: date)
        let df = DateFormatter()
        df.dateFormat = "EEEE"
        let day = df.string(from: date)
        switch hour {
        case 5..<12:  return "\(day) Morning"
        case 12..<17: return "\(day) Afternoon"
        case 17..<21: return "\(day) Evening"
        default:      return "\(day) Night"
        }
    }
}
