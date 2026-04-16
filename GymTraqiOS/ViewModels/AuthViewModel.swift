import Foundation

@Observable
class AuthViewModel {
    var email = ""
    var password = ""
    var isLoading = false
    var errorMessage: String?

    var isAuthenticated: Bool { APIService.shared.isAuthenticated }

    func login() async {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await APIService.shared.login(email: email, password: password)
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
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func logout() {
        APIService.shared.logout()
        email = ""
        password = ""
    }
}
