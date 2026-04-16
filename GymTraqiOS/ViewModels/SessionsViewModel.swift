import Foundation

@Observable
class SessionsViewModel {
    var sessions: [WorkoutSession] = []
    var isLoading = false
    var errorMessage: String?

    func load() async {
        isLoading = true
        do {
            sessions = try await APIService.shared.getSessions()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func create(date: String, notes: String?) async {
        do {
            let session = try await APIService.shared.createSession(date: date, notes: notes)
            sessions.insert(session, at: 0)
        } catch {
            errorMessage = error.localizedDescription
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
}
