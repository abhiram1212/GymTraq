import Foundation

@Observable
class AuthViewModel {
    var email = ""
    var password = ""
    var isLoading = false
    var errorMessage: String?

    // Computed from APIService (also @Observable) so any token change — login, logout,
    // or the automatic 401 sign-out in APIService — flips the app between Auth and Home.
    var isAuthenticated: Bool { APIService.shared.isAuthenticated }

    func login() async {
        isLoading = true
        errorMessage = nil
        do {
            try await APIService.shared.login(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signup() async {
        errorMessage = nil
        // Mirror server-side rules so users get instant feedback instead of a round trip
        guard email.contains("@"), email.contains(".") else {
            errorMessage = "Enter a valid email address."
            return
        }
        guard password.count >= 8 else {
            errorMessage = "Password must be at least 8 characters."
            return
        }
        isLoading = true
        do {
            try await APIService.shared.signup(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func logout() {
        APIService.shared.logout()
        ExerciseStore.shared.invalidate() // singleton caches must not leak to the next account
        UserStore.shared.invalidate()
        email = ""
        password = ""
    }
}
