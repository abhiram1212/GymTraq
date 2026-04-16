import Foundation

@Observable
class SessionsViewModel {
    var sessions: [WorkoutSession] = []
    var allEntries: [Entry] = []
    var allExercises: [Exercise] = []
    var isLoading = false
    var errorMessage: String?

    func load() async {
        isLoading = true
        async let s  = APIService.shared.getSessions()
        async let e  = APIService.shared.getAllEntries()
        async let ex = APIService.shared.getExercises()
        sessions     = (try? await s)  ?? []
        allEntries   = (try? await e)  ?? []
        allExercises = (try? await ex) ?? []
        isLoading = false
    }

    func create(date: String, notes: String?, name: String?) async {
        do {
            let session = try await APIService.shared.createSession(date: date, notes: notes, name: name)
            sessions.insert(session, at: 0)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func update(session: WorkoutSession) {
        if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[idx] = session
        }
    }

    func delete(session: WorkoutSession) async {
        do {
            try await APIService.shared.deleteSession(id: session.session_id)
            sessions.removeAll { $0.id == session.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func exerciseSummary(for sessionId: Int) -> String {
        let sessionEntries = allEntries.filter { $0.session_id == sessionId }
        guard !sessionEntries.isEmpty else { return "No exercises logged" }
        let exMap = Dictionary(uniqueKeysWithValues: allExercises.map { ($0.exercise_id, $0.exercise_name) })
        var seen = Set<Int>()
        var order = [Int]()
        for e in sessionEntries {
            if !seen.contains(e.exercise_id) { seen.insert(e.exercise_id); order.append(e.exercise_id) }
        }
        return order.map { exId in
            let count = sessionEntries.filter { $0.exercise_id == exId }.count
            return "\(count)x \(exMap[exId] ?? "Unknown")"
        }.joined(separator: ", ")
    }
}
