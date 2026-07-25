import Foundation

struct WorkoutStats {
    var workouts = 0
    var totalSets = 0
    var totalVolumeKg = 0.0
    var thisWeek = 0
    var favoriteExercise: String?

    var volumeLabel: String {
        totalVolumeKg >= 1000
            ? String(format: "%.1fk", totalVolumeKg / 1000)
            : String(format: "%.0f", totalVolumeKg)
    }
}

@Observable
class ProfileViewModel {
    var isLoading = false
    var isSaving = false
    var isUploadingPhoto = false
    var isEditing = false
    var errorMessage: String?
    var successMessage: String?
    var stats = WorkoutStats()
    var statsLoaded = false

    // Profile lives in the shared store so the Home header stays in sync
    var user: User? { UserStore.shared.user }

    // Edit fields (weightText/heightText hold values in the user's chosen unit)
    var weightText = ""
    var heightText = ""   // used when height unit is cm
    var feetText = ""     // used when height unit is ft/in
    var inchesText = ""
    var ageText = ""
    var sex = ""

    // Change password fields
    var currentPassword = ""
    var newPassword = ""
    var confirmPassword = ""
    var isChangingPassword = false
    var isDeletingAccount = false

    func load() async {
        isLoading = user == nil
        await UserStore.shared.loadIfNeeded()
        populateFields()
        isLoading = false
        await loadStats()
    }

    private func populateFields() {
        let units = UnitSettings.shared
        // Weight: stored kg → display unit
        weightText = user?.weight.map { units.trim(units.weight.fromKg($0)) } ?? ""
        // Height: stored cm → cm field or ft+in fields
        if let cm = user?.height {
            heightText = units.trim(cm)
            let (f, i) = HeightUnit.ftin.feetInches(fromCm: cm)
            feetText = "\(f)"; inchesText = "\(i)"
        } else {
            heightText = ""; feetText = ""; inchesText = ""
        }
        ageText = user?.age.map { String($0) } ?? ""
        sex     = user?.sex ?? ""
    }

    func beginEditing() {
        populateFields()
        errorMessage = nil
        successMessage = nil
        isEditing = true
    }

    func cancelEditing() {
        populateFields()
        errorMessage = nil
        isEditing = false
    }

    func save() async {
        guard let id = APIService.shared.userId else { return }
        let units = UnitSettings.shared
        errorMessage = nil
        successMessage = nil

        // Weight: entered in display unit → convert to kg for storage
        var weightKg: Double?
        if !weightText.isEmpty {
            guard let entered = parseDecimal(weightText) else {
                errorMessage = "Weight must be a number."; return
            }
            weightKg = units.weight.toKg(entered)
        }

        // Height: cm field, or feet+inches → convert to cm for storage
        var heightCm: Double?
        switch units.height {
        case .cm:
            if !heightText.isEmpty {
                guard let cm = parseDecimal(heightText) else {
                    errorMessage = "Height must be a number."; return
                }
                heightCm = cm
            }
        case .ftin:
            if !feetText.isEmpty || !inchesText.isEmpty {
                guard let f = Int(feetText.isEmpty ? "0" : feetText),
                      let i = Int(inchesText.isEmpty ? "0" : inchesText) else {
                    errorMessage = "Height must be whole numbers."; return
                }
                heightCm = HeightUnit.ftin.cm(fromFeet: f, inches: i)
            }
        }

        let age = Int(ageText)
        if !ageText.isEmpty && age == nil {
            errorMessage = "Age must be a whole number."; return
        }

        isSaving = true
        do {
            let updated = try await APIService.shared.updateUser(
                id: id, weight: weightKg, height: heightCm, age: age,
                sex: sex.isEmpty ? nil : sex
            )
            UserStore.shared.user = updated
            successMessage = "Profile saved."
            isEditing = false
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }

    func uploadPhoto(_ jpegData: Data) async {
        guard let id = APIService.shared.userId else { return }
        isUploadingPhoto = true
        errorMessage = nil
        do {
            let updated = try await APIService.shared.updateProfilePic(
                id: id, base64: jpegData.base64EncodedString()
            )
            UserStore.shared.user = updated
        } catch {
            errorMessage = error.localizedDescription
        }
        isUploadingPhoto = false
    }

    // MARK: - Training stats

    func loadStats() async {
        do {
            async let s = APIService.shared.getSessions()
            async let e = APIService.shared.getAllEntries()
            async let storeLoad: Void = ExerciseStore.shared.loadIfNeeded()
            let sessions = try await s
            let entries  = try await e
            await storeLoad

            var result = WorkoutStats()
            result.workouts = sessions.count
            result.totalSets = entries.count
            result.totalVolumeKg = entries.reduce(0) { $0 + $1.weight * Double($1.reps) }

            let parser = DateFormatter()
            parser.dateFormat = "yyyy-MM-dd"
            let weekStart = Calendar.current.date(
                byAdding: .day, value: -6,
                to: Calendar.current.startOfDay(for: Date())
            )!
            result.thisWeek = sessions.filter {
                guard let d = parser.date(from: $0.date) else { return false }
                return d >= weekStart
            }.count

            if let top = Dictionary(grouping: entries, by: \.exercise_id)
                .max(by: { $0.value.count < $1.value.count }) {
                result.favoriteExercise = ExerciseStore.shared.exercises
                    .first { $0.exercise_id == top.key }?.exercise_name
            }

            stats = result
            statsLoaded = true
        } catch {
            // Stats are decorative — don't block the profile over them
        }
    }

    // MARK: - Derived

    var memberSince: String? {
        guard let iso = user?.created_at else { return nil }
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        guard let date = withFraction.date(from: iso) ?? plain.date(from: iso) else { return nil }
        let out = DateFormatter()
        out.dateFormat = "MMMM yyyy"
        return out.string(from: date)
    }

    var bmi: (value: Double, label: String)? {
        guard let w = user?.weight, let h = user?.height, h > 0 else { return nil }
        let v = w / ((h / 100) * (h / 100))
        let label = v < 18.5 ? "Underweight" : v < 25 ? "Healthy" : v < 30 ? "Overweight" : "Obese"
        return (v, label)
    }

    // MARK: - Delete account

    @discardableResult
    func deleteAccount() async -> Bool {
        guard let id = APIService.shared.userId else { return false }
        isDeletingAccount = true
        errorMessage = nil
        do {
            try await APIService.shared.deleteAccount(id: id)
            isDeletingAccount = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isDeletingAccount = false
            return false
        }
    }

    // MARK: - Password

    func changePassword() async {
        guard let id = APIService.shared.userId else { return }
        guard newPassword == confirmPassword else {
            errorMessage = "New passwords don't match."
            return
        }
        guard newPassword.count >= 8 else {
            errorMessage = "New password must be at least 8 characters."
            return
        }
        isChangingPassword = true
        errorMessage = nil
        successMessage = nil
        do {
            try await APIService.shared.changePassword(
                id: id, currentPassword: currentPassword, newPassword: newPassword
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
