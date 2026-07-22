import Foundation

/// Single source of truth for the exercise catalog.
/// Exercises change rarely but were being re-fetched by three different screens
/// on every tab switch — this store fetches once, dedupes concurrent requests,
/// and serves every screen from memory. Pull-to-refresh calls `refresh()`.
@Observable
class ExerciseStore {
    static let shared = ExerciseStore()
    private init() {}

    var exercises: [Exercise] = []
    var isLoading = false
    var errorMessage: String?

    private var hasLoaded = false
    private var inFlight: Task<Void, Never>?

    /// Cache-first: returns immediately if the catalog is already in memory.
    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await refresh()
    }

    /// Force a network fetch. Concurrent callers await the same request
    /// instead of firing duplicates.
    func refresh() async {
        if let inFlight {
            await inFlight.value
            return
        }
        let task = Task {
            // Only show a spinner when there's nothing cached to display
            isLoading = exercises.isEmpty
            errorMessage = nil
            do {
                exercises = try await APIService.shared.getExercises()
                hasLoaded = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
        inFlight = task
        await task.value
        inFlight = nil
    }

    /// Create on the server and update the cache in place — no refetch needed.
    func add(name: String, muscleGroup: String?) async throws -> Exercise {
        let ex = try await APIService.shared.createExercise(name: name, muscleGroup: muscleGroup)
        exercises.append(ex)
        exercises.sort { $0.exercise_name < $1.exercise_name }
        return ex
    }

    /// Rename / re-categorize on the server, then update the cache in place.
    func update(id: Int, name: String, muscleGroup: String?) async throws -> Exercise {
        let updated = try await APIService.shared.updateExercise(id: id, name: name, muscleGroup: muscleGroup)
        if let idx = exercises.firstIndex(where: { $0.exercise_id == id }) {
            exercises[idx] = updated
        }
        exercises.sort { $0.exercise_name < $1.exercise_name }
        return updated
    }

    /// Delete on the server, then drop from the cache.
    func delete(id: Int) async throws {
        try await APIService.shared.deleteExercise(id: id)
        exercises.removeAll { $0.exercise_id == id }
    }

    /// Clear on logout so the next user doesn't see a stale catalog.
    func invalidate() {
        hasLoaded = false
        exercises = []
        errorMessage = nil
    }
}
