import SwiftUI

struct ExercisesView: View {
    @State private var vm = ExercisesViewModel()
    @State private var showAdd = false
    @State private var newName = ""
    @State private var searchText = ""

    var filtered: [Exercise] {
        searchText.isEmpty ? vm.exercises
            : vm.exercises.filter { $0.exercise_name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ZStack {
            AnimatedBackground()

            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Exercises")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("\(vm.exercises.count) in your library")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 60)
                .padding(.bottom, 16)

                // Search
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.white.opacity(0.4))
                    TextField("Search exercises", text: $searchText)
                        .foregroundStyle(.white)
                }
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
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
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(filtered) { exercise in
                                GlassCard(padding: 16) {
                                    HStack {
                                        Image(systemName: "figure.strengthtraining.traditional")
                                            .font(.system(size: 18))
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: [Color(red: 0.4, green: 0.7, blue: 1.0),
                                                             Color(red: 0.6, green: 0.3, blue: 1.0)],
                                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 36, height: 36)
                                            .background(.white.opacity(0.08), in: Circle())
                                        Text(exercise.exercise_name)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundStyle(.white)
                                        Spacer()
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 120)
                    }
                    .scrollIndicators(.hidden)
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
            addSheet
        }
        .colorScheme(.dark)
    }

    private var addSheet: some View {
        ZStack {
            AnimatedBackground()
            VStack(spacing: 24) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(.white.opacity(0.3))
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)

                Text("New Exercise")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                GlassCard {
                    GlassTextField(placeholder: "Exercise name", icon: "dumbbell", text: $newName)
                }
                .padding(.horizontal, 20)

                GlassButton("Add Exercise", icon: "plus.circle.fill") {
                    let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty else { return }
                    Task {
                        await vm.create(name: name)
                        newName = ""
                        showAdd = false
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
        .colorScheme(.dark)
    }
}
