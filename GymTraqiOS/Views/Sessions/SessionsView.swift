import SwiftUI

struct SessionsView: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var vm = SessionsViewModel()
    @State private var showAdd = false
    @State private var selectedSession: WorkoutSession?

    var body: some View {
        ZStack {
            AnimatedBackground()

            VStack(spacing: 0) {
                // Header
                header
                    .padding(.horizontal, 24)
                    .padding(.top, 60)
                    .padding(.bottom, 20)

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

            // FAB
            VStack {
                Spacer()
                HStack {
                    Spacer()
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
                    .padding(.trailing, 24)
                    .padding(.bottom, 100)
                }
            }
        }
        .task { await vm.load() }
        .sheet(isPresented: $showAdd) {
            AddSessionSheet(vm: vm)
        }
        .sheet(item: $selectedSession) { session in
            SessionDetailView(session: session)
        }
        .colorScheme(.dark)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Workouts")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("\(vm.sessions.count) sessions logged")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            Button(role: .none) {
                authVM.logout()
            } label: {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(10)
                    .background(.white.opacity(0.08), in: Circle())
            }
        }
    }

    private var sessionList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(vm.sessions) { session in
                    SessionCard(session: session)
                        .onTapGesture { selectedSession = session }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task { await vm.delete(session: session) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
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
}

struct SessionCard: View {
    let session: WorkoutSession

    var body: some View {
        GlassCard {
            HStack(spacing: 16) {
                // Date badge
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
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(session.dayOfWeek)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(session.notes ?? "No notes")
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

struct AddSessionSheet: View {
    var vm: SessionsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()
    @State private var notes = ""
    @State private var isLoading = false

    var body: some View {
        ZStack {
            AnimatedBackground()
            VStack(spacing: 24) {
                // Handle
                RoundedRectangle(cornerRadius: 3)
                    .fill(.white.opacity(0.3))
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)

                Text("New Session")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                GlassCard {
                    VStack(spacing: 16) {
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
                    Task {
                        await vm.create(date: formatter.string(from: date),
                                       notes: notes.isEmpty ? nil : notes)
                        dismiss()
                    }
                }
                .padding(.horizontal, 20)
                .disabled(isLoading)

                Spacer()
            }
        }
        .colorScheme(.dark)
    }
}
