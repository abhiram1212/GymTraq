import Foundation

@Observable
class SessionsViewModel {
    var sessions: [WorkoutSession] = []
    var allEntries: [Entry] = []
    var isLoading = false
    var errorMessage: String?

    // Exercise names come from the shared cached catalog — no separate fetch here
    var allExercises: [Exercise] { ExerciseStore.shared.exercises }

    private var hasLoaded = false

    /// Cache-first — tab switches after the first load cost zero requests.
    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await load()
    }

    func load() async {
        // Full-screen spinner only when there's nothing to show yet;
        // refreshes update in place without blanking the list
        isLoading = sessions.isEmpty
        errorMessage = nil
        do {
            async let s = APIService.shared.getSessions()
            async let e = APIService.shared.getAllEntries()
            async let storeLoad: Void = ExerciseStore.shared.loadIfNeeded()
            sessions   = try await s
            allEntries = try await e
            await storeLoad
            hasLoaded = true
        } catch {
            // Surface the failure — an empty list from a network error must not
            // masquerade as "no sessions yet"
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Re-fetch entries after the detail sheet closes so session-card summaries stay current.
    func refreshEntries() async {
        allEntries = (try? await APIService.shared.getAllEntries()) ?? allEntries
    }

    @discardableResult
    func create(date: String, notes: String?, name: String?) async -> Bool {
        do {
            let session = try await APIService.shared.createSession(date: date, notes: notes, name: name)
            sessions.insert(session, at: 0)
            // Keep server order (date DESC) — a back-dated session must not sit at the top.
            // "yyyy-MM-dd" strings compare correctly lexicographically.
            sessions.sort { ($0.date, $0.session_id) > ($1.date, $1.session_id) }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
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

    /// Duplicate a past session (name + all sets) into today — "repeat leg day".
    @discardableResult
    func repeatSession(_ source: WorkoutSession) async -> Bool {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        do {
            let newSession = try await APIService.shared.createSession(
                date: df.string(from: Date()), notes: nil, name: source.name
            )
            let sourceEntries = allEntries
                .filter { $0.session_id == source.session_id }
                .sorted { ($0.exercise_id, $0.set_number) < ($1.exercise_id, $1.set_number) }
            for e in sourceEntries {
                let created = try await APIService.shared.createEntry(
                    setNumber: e.set_number, reps: e.reps, weight: e.weight,
                    sessionId: newSession.session_id, exerciseId: e.exercise_id
                )
                allEntries.append(created)
            }
            sessions.insert(newSession, at: 0)
            sessions.sort { ($0.date, $0.session_id) > ($1.date, $1.session_id) }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Weekly goal & streak

    private static let ymd: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    var thisWeekCount: Int {
        guard let week = Calendar.current.dateInterval(of: .weekOfYear, for: Date()) else { return 0 }
        return sessions.filter {
            guard let d = Self.ymd.date(from: $0.date) else { return false }
            return week.contains(d)
        }.count
    }

    /// Consecutive calendar weeks with at least one workout. The current week
    /// doesn't break the streak while it's still in progress.
    var weekStreak: Int {
        let cal = Calendar.current
        let weekStarts = Set(sessions.compactMap { s -> Date? in
            guard let d = Self.ymd.date(from: s.date) else { return nil }
            return cal.dateInterval(of: .weekOfYear, for: d)?.start
        })
        guard var cursor = cal.dateInterval(of: .weekOfYear, for: Date())?.start else { return 0 }
        if !weekStarts.contains(cursor) {
            guard let prev = cal.date(byAdding: .weekOfYear, value: -1, to: cursor) else { return 0 }
            cursor = prev
        }
        var streak = 0
        while weekStarts.contains(cursor) {
            streak += 1
            guard let prev = cal.date(byAdding: .weekOfYear, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
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
