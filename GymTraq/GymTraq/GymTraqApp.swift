import SwiftUI

@main
struct GymTraqApp: App {
    @State private var authVM = AuthViewModel()
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                if showSplash {
                    SplashView()
                        .transition(.opacity)
                } else {
                    Group {
                        if authVM.isAuthenticated {
                            HomeView()
                        } else {
                            AuthView()
                        }
                    }
                    .environment(authVM)
                    .animation(.spring(duration: 0.4), value: authVM.isAuthenticated)
                    .transition(.opacity)
                }
            }
            .task {
                // Prefetch data behind the splash so the first screen lands warm
                async let warm: Void = prefetch()
                try? await Task.sleep(for: .seconds(1.3)) // minimum splash time
                await warm
                withAnimation(.easeInOut(duration: 0.45)) { showSplash = false }
            }
        }
    }

    private func prefetch() async {
        guard APIService.shared.isAuthenticated else { return }
        await UserStore.shared.loadIfNeeded()
        await ExerciseStore.shared.loadIfNeeded()
    }
}
