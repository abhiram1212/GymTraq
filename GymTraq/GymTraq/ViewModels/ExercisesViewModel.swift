import Foundation

@Observable
class ExercisesViewModel {
    private let store = ExerciseStore.shared

    // Served from the shared cache — no per-screen copies, no duplicate fetches
    var exercises: [Exercise] { store.exercises }
    var isLoading: Bool { store.isLoading }
    var errorMessage: String?

    /// Cache-first — free on tab switches after the first load.
    func loadIfNeeded() async {
        await store.loadIfNeeded()
        errorMessage = store.errorMessage
    }

    /// Explicit refresh (pull-to-refresh, retry button).
    func load() async {
        await store.refresh()
        errorMessage = store.errorMessage
    }

    @discardableResult
    func create(name: String, muscleGroup: String?) async -> Bool {
        do {
            _ = try await store.add(name: name, muscleGroup: muscleGroup)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func update(id: Int, name: String, muscleGroup: String?) async -> Bool {
        do {
            _ = try await store.update(id: id, name: name, muscleGroup: muscleGroup)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func delete(_ exercise: Exercise) async -> Bool {
        do {
            try await store.delete(id: exercise.exercise_id)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
