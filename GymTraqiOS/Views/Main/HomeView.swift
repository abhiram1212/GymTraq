import SwiftUI

struct HomeView: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var selectedTab = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                SessionsView()
                    .tag(0)
                ExercisesView()
                    .tag(1)
                ChatView()
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Floating glass tab bar
            floatingTabBar
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
        }
        .background(Color.black.ignoresSafeArea())
        .colorScheme(.dark)
    }

    private var floatingTabBar: some View {
        HStack(spacing: 0) {
            tabItem(icon: "calendar.badge.plus", label: "Sessions", tag: 0)
            tabItem(icon: "figure.strengthtraining.traditional", label: "Exercises", tag: 1)
            tabItem(icon: "sparkles", label: "AI Coach", tag: 2)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.15), lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 20, y: 8)
    }

    private func tabItem(icon: String, label: String, tag: Int) -> some View {
        Button {
            withAnimation(.spring(duration: 0.35)) { selectedTab = tag }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: selectedTab == tag ? .bold : .regular))
                    .symbolEffect(.bounce, value: selectedTab == tag)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(
                selectedTab == tag
                    ? AnyShapeStyle(LinearGradient(
                        colors: [Color(red: 0.4, green: 0.7, blue: 1.0),
                                 Color(red: 0.6, green: 0.3, blue: 1.0)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    : AnyShapeStyle(.white.opacity(0.35))
            )
        }
        .buttonStyle(.plain)
    }
}
