import SwiftUI

@main
struct GymTraqApp: App {
    @State private var authVM = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if authVM.isAuthenticated {
                    HomeView()
                } else {
                    AuthView()
                }
            }
            .environment(authVM)
            .animation(.spring(duration: 0.4), value: authVM.isAuthenticated)
        }
    }
}
