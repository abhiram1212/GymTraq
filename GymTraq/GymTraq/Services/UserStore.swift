import Foundation

/// Shared cached profile — the Profile screen edits it, the Home header reads it,
/// so an avatar change shows up everywhere immediately without refetching.
@Observable
class UserStore {
    static let shared = UserStore()
    private init() {}

    var user: User?
    private var inFlight: Task<Void, Never>?

    func loadIfNeeded() async {
        guard user == nil else { return }
        await refresh()
    }

    func refresh() async {
        if let inFlight {
            await inFlight.value
            return
        }
        guard let id = APIService.shared.userId else { return }
        let task = Task {
            user = try? await APIService.shared.getUser(id: id)
        }
        inFlight = task
        await task.value
        inFlight = nil
    }

    func invalidate() { user = nil }
}
