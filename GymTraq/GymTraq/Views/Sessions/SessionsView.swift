import SwiftUI

struct SessionsView: View {
    @Environment(AuthViewModel.self) private var authVM
    // Owned by HomeView and shared with the Progress tab
    var vm: SessionsViewModel
    @AppStorage("weeklyGoal") private var weeklyGoal = 3
    @State private var showAdd = false
    @State private var showProfile = false
    @State private var selectedSession: WorkoutSession?
    @State private var sessionToDelete: WorkoutSession?
    @State private var selectedDate = Date()
    @State private var calendarMonth = Date()

    private static let ymd: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.calendar = .current; return f
    }()

    // Days that have at least one workout — drives the calendar dots
    private var workoutDates: Set<String> { Set(vm.sessions.map(\.date)) }

    // Sessions on the selected calendar day
    private var daySessions: [WorkoutSession] {
        let key = Self.ymd.string(from: selectedDate)
        return vm.sessions.filter { $0.date == key }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 16)

            // Action failures (e.g. delete) when a list is showing — the full-screen
            // error state below only covers load failures on an empty list
            if let err = vm.errorMessage, !vm.sessions.isEmpty {
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
                    vm.errorMessage = nil
                }
            }

            if vm.isLoading {
                Spacer()
                ProgressView().tint(.white)
                Spacer()
            } else if let err = vm.errorMessage, vm.sessions.isEmpty {
                errorState(err)
            } else if vm.sessions.isEmpty {
                emptyState
            } else {
                calendarScroll
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .bottomTrailing) {
            fabButton
                .padding(.trailing, 24)
                .padding(.bottom, 16)
        }
        .background { AnimatedBackground() }
        .task {
            await vm.loadIfNeeded()
            await UserStore.shared.loadIfNeeded() // header avatar
        }
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
            AddSessionSheet(vm: vm, initialDate: selectedDate)
        }
        .sheet(item: $selectedSession, onDismiss: {
            // Sets added/removed in the detail view change the card summaries
            Task { await vm.refreshEntries() }
        }) { session in
            SessionDetailView(
                session: session,
                historySessions: vm.sessions,
                historyEntries: vm.allEntries
            ) { updated in
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
                // Live profile picture — updates the moment it's changed in Profile
                AvatarView(user: UserStore.shared.user, size: 38)
            }
            .buttonStyle(PressableCardStyle())
        }
    }

    // MARK: - Calendar + selected-day list

    private var calendarScroll: some View {
        ScrollView {
            VStack(spacing: 14) {
                weeklyGoalCard
                WorkoutCalendarView(
                    workoutDates: workoutDates,
                    selectedDate: $selectedDate,
                    month: $calendarMonth
                )
                selectedDaySection
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
        .refreshable { await vm.load() }
    }

    private var selectedDaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(selectedDayTitle)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
                if !daySessions.isEmpty {
                    Text("\(daySessions.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
            .padding(.top, 4)

            if daySessions.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "moon.zzz")
                        .font(.system(size: 30))
                        .foregroundStyle(.white.opacity(0.15))
                    Text("No workout logged")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.35))
                    Button { showAdd = true } label: {
                        Text("Log one")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 18).padding(.vertical, 9)
                            .background(Color.appAccent, in: Capsule())
                    }
                    .buttonStyle(PressableCardStyle())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
            } else {
                ForEach(daySessions) { session in
                    Button { selectedSession = session } label: {
                        SessionCard(session: session, summary: vm.exerciseSummary(for: session.session_id))
                    }
                    .buttonStyle(PressableCardStyle())
                    .contextMenu {
                        Button {
                            Task { await vm.repeatSession(session) }
                        } label: {
                            Label("Repeat Workout Today", systemImage: "arrow.clockwise")
                        }
                        Button(role: .destructive) {
                            sessionToDelete = session
                        } label: {
                            Label("Delete Session", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    private var selectedDayTitle: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return Calendar.current.isDateInToday(selectedDate) ? "Today" : f.string(from: selectedDate)
    }

    // MARK: - Weekly goal & streak

    private var weeklyGoalCard: some View {
        GlassCard(padding: 14) {
            HStack(spacing: 16) {
                // Fitness-style progress ring
                ZStack {
                    Circle()
                        .stroke(Color.appCardElevated, lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: min(1, CGFloat(vm.thisWeekCount) / CGFloat(max(1, weeklyGoal))))
                        .stroke(Color.appAccent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(duration: 0.6), value: vm.thisWeekCount)
                    Text("\(vm.thisWeekCount)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(vm.thisWeekCount) of \(weeklyGoal) workouts this week")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(vm.weekStreak > 0 ? .orange : .white.opacity(0.25))
                        Text(vm.weekStreak > 0
                             ? "\(vm.weekStreak)-week streak"
                             : "Log a workout to start a streak")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }

                Spacer()

                Menu {
                    Picker("Weekly goal", selection: $weeklyGoal) {
                        ForEach(1..<8) { n in
                            Text("\(n) per week").tag(n)
                        }
                    }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(8)
                        .background(Color.appCardElevated, in: Circle())
                }
            }
        }
    }

    // MARK: - Error state

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 50))
                .foregroundStyle(.white.opacity(0.2))
            Text("Couldn't load workouts")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white.opacity(0.5))
            Text(message)
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
            .padding(.top, 4)
            Spacer()
        }
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
                .shadow(color: Color.appAccent.opacity(0.5),
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
    @State private var date: Date
    @State private var notes = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    init(vm: SessionsViewModel, initialDate: Date = Date()) {
        self.vm = vm
        // Default the picker to the day selected in the calendar (capped at today)
        _date = State(initialValue: min(initialDate, Date()))
    }

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

                    DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
                        .foregroundStyle(.white)
                        .colorScheme(.dark)

                    Divider().background(.white.opacity(0.1))

                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .foregroundStyle(.white)
                        .lineLimit(3...5)
                }
            }
            .padding(.horizontal, 20)

            if let err = errorMessage {
                Text(err).font(.caption)
                    .foregroundStyle(Color.appDanger)
                    .padding(.horizontal, 20)
            }

            GlassButton(isLoading ? "Logging..." : "Log Session", icon: "checkmark.circle.fill") {
                isLoading = true
                errorMessage = nil
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                let trimmed = sessionName.trimmingCharacters(in: .whitespacesAndNewlines)
                let finalName = trimmed.isEmpty ? timeOfDayName(for: date) : trimmed
                Task {
                    let ok = await vm.create(
                        date: formatter.string(from: date),
                        notes: notes.isEmpty ? nil : notes,
                        name: finalName
                    )
                    isLoading = false
                    if ok {
                        dismiss()
                    } else {
                        // Keep the sheet open so nothing is silently lost
                        errorMessage = vm.errorMessage ?? "Couldn't save the session."
                    }
                }
            }
            .padding(.horizontal, 20)
            .disabled(isLoading)
            .opacity(isLoading ? 0.6 : 1)

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
