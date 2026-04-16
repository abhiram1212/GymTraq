import Foundation

@Observable
class ExercisesViewModel {
    var exercises: [Exercise] = []
    var isLoading = false
    var errorMessage: String?

    func load() async {
        isLoading = true
        do {
            exercises = try await APIService.shared.getExercises()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func create(name: String, muscleGroup: String?) async {
        do {
            let ex = try await APIService.shared.createExercise(name: name, muscleGroup: muscleGroup)
            exercises.append(ex)
            exercises.sort { $0.exercise_name < $1.exercise_name }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
