import SwiftUI

struct HomeView: View {
    @State private var selectedTab = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                SessionsView().tag(0)
                ExercisesView().tag(1)
                ChatView().tag(2)
            }
            // Hide native system tab bar — we use our own floating one
            .toolbar(.hidden, for: .tabBar)
            // Reserve space so scroll content never hides behind our tab bar
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: 88)
            }

            floatingTabBar
                .padding(.horizontal, 28)
                .padding(.bottom, 8)
        }
        .background(Color.black.ignoresSafeArea())
        .colorScheme(.dark)
    }

    private var floatingTabBar: some View {
        HStack(spacing: 0) {
            tabItem(icon: "calendar.badge.plus",                   label: "Sessions",  tag: 0)
            tabItem(icon: "figure.strengthtraining.traditional",   label: "Exercises", tag: 1)
            tabItem(icon: "sparkles",                              label: "AI Coach",  tag: 2)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .glassEffect(in: .capsule)
        .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
    }

    private func tabItem(icon: String, label: String, tag: Int) -> some View {
        Button {
            withAnimation(.spring(duration: 0.3)) { selectedTab = tag }
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
