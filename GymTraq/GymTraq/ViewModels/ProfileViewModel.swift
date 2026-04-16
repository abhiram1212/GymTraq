import Foundation

@Observable
class ProfileViewModel {
    var user: User?
    var isLoading = false
    var isSaving = false
    var errorMessage: String?
    var successMessage: String?

    // Edit fields
    var weightText = ""
    var heightText = ""
    var ageText = ""
    var sex = ""

    // Change password fields
    var currentPassword = ""
    var newPassword = ""
    var confirmPassword = ""
    var isChangingPassword = false

    func load() async {
        guard let id = APIService.shared.userId else { return }
        isLoading = true
        do {
            let u = try await APIService.shared.getUser(id: id)
            user = u
            weightText = u.weight.map { String($0) } ?? ""
            heightText = u.height.map { String($0) } ?? ""
            ageText    = u.age.map    { String($0) } ?? ""
            sex        = u.sex ?? ""
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func save() async {
        guard let id = APIService.shared.userId else { return }
        isSaving = true
        errorMessage = nil
        successMessage = nil
        do {
            let updated = try await APIService.shared.updateUser(
                id: id,
                weight: Double(weightText),
                height: Double(heightText),
                age:    Int(ageText),
                sex:    sex.isEmpty ? nil : sex
            )
            user = updated
            successMessage = "Profile saved."
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }

    func changePassword() async {
        guard let id = APIService.shared.userId else { return }
        guard newPassword == confirmPassword else {
            errorMessage = "New passwords don't match."
            return
        }
        guard newPassword.count >= 6 else {
            errorMessage = "New password must be at least 6 characters."
            return
        }
        isChangingPassword = true
        errorMessage = nil
        successMessage = nil
        do {
            try await APIService.shared.changePassword(
                id: id,
                currentPassword: currentPassword,
                newPassword: newPassword
            )
            currentPassword = ""
            newPassword = ""
            confirmPassword = ""
            successMessage = "Password changed successfully."
        } catch {
            errorMessage = error.localizedDescription
        }
        isChangingPassword = false
    }
}
