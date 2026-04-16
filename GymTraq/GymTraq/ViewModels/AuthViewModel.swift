import Foundation

@Observable
class AuthViewModel {
    var email = ""
    var password = ""
    var isLoading = false
    var errorMessage: String?

    // Stored property — @Observable tracks this directly, so GymTraqApp re-renders on change
    var isAuthenticated: Bool

    init() {
        self.isAuthenticated = APIService.shared.isAuthenticated
    }

    func login() async {
        isLoading = true
        errorMessage = nil
        do {
            try await APIService.shared.login(email: email, password: password)
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signup() async {
        isLoading = true
        errorMessage = nil
        do {
            try await APIService.shared.signup(email: email, password: password)
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func logout() {
        APIService.shared.logout()
        isAuthenticated = false
        email = ""
        password = ""
    }
}
