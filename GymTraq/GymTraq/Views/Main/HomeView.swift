import SwiftUI

struct HomeView: View {
    @State private var selectedTab = 0
    @Namespace private var tabHighlight
    // Shared between the Workouts and Progress tabs — one fetch feeds both
    @State private var sessionsVM = SessionsViewModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                // Both modifiers must be on each tab's CONTENT, not the TabView:
                // .toolbar hides the system Liquid Glass bar, and .safeAreaInset
                // reserves room for our floating bar (FABs, chat input included)
                SessionsView(vm: sessionsVM).tag(0)
                    .toolbar(.hidden, for: .tabBar)
                    .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: 88) }
                ProgressTabView(vm: sessionsVM).tag(1)
                    .toolbar(.hidden, for: .tabBar)
                    .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: 88) }
                ExercisesView().tag(2)
                    .toolbar(.hidden, for: .tabBar)
                    .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: 88) }
                ChatView().tag(3)
                    .toolbar(.hidden, for: .tabBar)
                    .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: 88) }
            }

            floatingTabBar
                .padding(.horizontal, 28)
                .padding(.bottom, 8)
        }
        .background(Color.black.ignoresSafeArea())
        .colorScheme(.dark)
    }

    private var floatingTabBar: some View {
        // GlassEffectContainer lets the bar's glass and the sliding
        // selection glass blend instead of stacking as separate layers
        GlassEffectContainer {
            HStack(spacing: 4) {
                tabItem(icon: "calendar.badge.plus",                 label: "Workouts",  tag: 0)
                tabItem(icon: "chart.line.uptrend.xyaxis",           label: "Progress",  tag: 1)
                tabItem(icon: "figure.strengthtraining.traditional", label: "Exercises", tag: 2)
                tabItem(icon: "sparkles",                            label: "Coach",     tag: 3)
            }
            .padding(6)
            .glassEffect(in: .capsule)
        }
        .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
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
            .padding(.vertical, 8)
            .foregroundStyle(
                selectedTab == tag
                    ? AnyShapeStyle(LinearGradient(
                        colors: [Color.appAccent,
                                 Color.appAccentDeep],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    : AnyShapeStyle(.white.opacity(0.35))
            )
            .background {
                // Plain accent capsule slides between tabs via matchedGeometry.
                // (An .interactive() glass pill here stole taps — its own gesture
                // recognizer competed with the button, needing 2–3 taps.)
                if selectedTab == tag {
                    Capsule()
                        .fill(Color.appAccent.opacity(0.16))
                        .matchedGeometryEffect(id: "selectedTab", in: tabHighlight)
                }
            }
            // Make the whole cell — including transparent padding — tappable
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
