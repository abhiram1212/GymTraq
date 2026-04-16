import Foundation

enum APIServiceError: LocalizedError {
    case serverError(String)
    case badResponse

    var errorDescription: String? {
        switch self {
        case .serverError(let msg): return msg
        case .badResponse: return "Unexpected server response."
        }
    }
}

@Observable
class APIService {
    static let shared = APIService()
    private let baseURL = "http://localhost:3000"

    // Stored property so @Observable tracks changes and triggers SwiftUI re-renders
    var token: String? {
        didSet {
            if let token {
                UserDefaults.standard.set(token, forKey: "gymtraq_token")
            } else {
                UserDefaults.standard.removeObject(forKey: "gymtraq_token")
            }
        }
    }

    private init() {
        // Rehydrate token from disk on launch
        self.token = UserDefaults.standard.string(forKey: "gymtraq_token")
    }

    var userId: Int? {
        guard let token else { return nil }
        return decodeJWT(token)
    }

    var isAuthenticated: Bool { token != nil }

    func logout() { token = nil }

    // MARK: - JWT decode (client-side, verification done by server)
    private func decodeJWT(_ token: String) -> Int? {
        let parts = token.components(separatedBy: ".")
        guard parts.count == 3 else { return nil }
        var b64 = parts[1]
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let rem = b64.count % 4
        if rem > 0 { b64 += String(repeating: "=", count: 4 - rem) }
        guard let data = Data(base64Encoded: b64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let uid = json["user_id"] as? Int else { return nil }
        return uid
    }

    // MARK: - Core request
    func request(
        _ path: String,
        method: String = "GET",
        body: [String: Any]? = nil,
        requiresAuth: Bool = true
    ) async throws -> Data {
        guard let url = URL(string: baseURL + path) else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if requiresAuth, let token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIServiceError.badResponse }
        guard (200...299).contains(http.statusCode) else {
            if let apiErr = try? JSONDecoder().decode(APIError.self, from: data) {
                throw APIServiceError.serverError(apiErr.error)
            }
            throw APIServiceError.badResponse
        }
        return data
    }

    // MARK: - Auth
    func signup(email: String, password: String) async throws {
        _ = try await request("/users", method: "POST",
                              body: ["email": email, "password": password],
                              requiresAuth: false)
        try await login(email: email, password: password)
    }

    @discardableResult
    func login(email: String, password: String) async throws -> AuthResponse {
        let data = try await request("/users/login", method: "POST",
                                     body: ["email": email, "password": password],
                                     requiresAuth: false)
        let resp = try JSONDecoder().decode(AuthResponse.self, from: data)
        token = resp.token
        return resp
    }

    // MARK: - User Profile
    func getUser(id: Int) async throws -> User {
        let data = try await request("/users/\(id)")
        return try JSONDecoder().decode(User.self, from: data)
    }

    func updateUser(id: Int, weight: Double?, height: Double?, age: Int?, sex: String?) async throws -> User {
        var body: [String: Any] = [:]
        if let weight { body["weight"] = weight }
        if let height { body["height"] = height }
        if let age    { body["age"]    = age    }
        if let sex    { body["sex"]    = sex    }
        let data = try await request("/users/\(id)", method: "PUT", body: body)
        return try JSONDecoder().decode(User.self, from: data)
    }

    func changePassword(id: Int, currentPassword: String, newPassword: String) async throws {
        _ = try await request("/users/\(id)/password", method: "PUT", body: [
            "currentPassword": currentPassword,
            "newPassword": newPassword
        ])
    }

    // MARK: - Sessions
    func getSessions() async throws -> [WorkoutSession] {
        let data = try await request("/sessions")
        return try JSONDecoder().decode([WorkoutSession].self, from: data)
    }

    func createSession(date: String, notes: String?, name: String?) async throws -> WorkoutSession {
        var body: [String: Any] = ["date": date]
        if let notes { body["notes"] = notes }
        if let name { body["name"] = name }
        let data = try await request("/sessions", method: "POST", body: body)
        return try JSONDecoder().decode(WorkoutSession.self, from: data)
    }

    func deleteSession(id: Int) async throws {
        _ = try await request("/sessions/\(id)", method: "DELETE")
    }

    // MARK: - Exercises
    func getExercises() async throws -> [Exercise] {
        let data = try await request("/exercises")
        return try JSONDecoder().decode([Exercise].self, from: data)
    }

    func createExercise(name: String, muscleGroup: String?) async throws -> Exercise {
        var body: [String: Any] = ["exercise_name": name]
        if let muscleGroup { body["muscle_group"] = muscleGroup }
        let data = try await request("/exercises", method: "POST", body: body)
        return try JSONDecoder().decode(Exercise.self, from: data)
    }

    func forgotPassword(email: String, newPassword: String) async throws {
        _ = try await request("/users/forgot-password", method: "POST",
                              body: ["email": email, "newPassword": newPassword],
                              requiresAuth: false)
    }

    // MARK: - Entries
    func getEntries(sessionId: Int) async throws -> [Entry] {
        let data = try await request("/entries?session_id=\(sessionId)")
        return try JSONDecoder().decode([Entry].self, from: data)
    }

    func createEntry(setNumber: Int, reps: Int, weight: Double,
                     sessionId: Int, exerciseId: Int) async throws -> Entry {
        let data = try await request("/entries", method: "POST", body: [
            "set_number": setNumber, "reps": reps, "weight": weight,
            "session_id": sessionId, "exercise_id": exerciseId
        ])
        return try JSONDecoder().decode(Entry.self, from: data)
    }

    func updateSession(id: Int, date: String, notes: String?, name: String?) async throws -> WorkoutSession {
        var body: [String: Any] = ["date": date]
        body["notes"] = notes ?? NSNull()
        if let name { body["name"] = name }
        let data = try await request("/sessions/\(id)", method: "PUT", body: body)
        return try JSONDecoder().decode(WorkoutSession.self, from: data)
    }

    func getAllEntries() async throws -> [Entry] {
        let data = try await request("/entries")
        return try JSONDecoder().decode([Entry].self, from: data)
    }

    func updateEntrySetNumber(id: Int, setNumber: Int) async throws {
        _ = try await request("/entries/\(id)", method: "PUT", body: ["set_number": setNumber])
    }

    func deleteEntry(id: Int) async throws {
        _ = try await request("/entries/\(id)", method: "DELETE")
    }

    func deleteEntriesByExercise(sessionId: Int, exerciseId: Int) async throws {
        _ = try await request("/entries/by-exercise", method: "DELETE", body: [
            "session_id": sessionId, "exercise_id": exerciseId
        ])
    }

    func replaceExercise(sessionId: Int, oldExerciseId: Int, newExerciseId: Int) async throws {
        _ = try await request("/entries/replace", method: "PUT", body: [
            "session_id": sessionId,
            "old_exercise_id": oldExerciseId,
            "new_exercise_id": newExerciseId
        ])
    }

    // MARK: - Chat
    func getChatHistory() async throws -> [ChatMessage] {
        let data = try await request("/ai-chat")
        return try JSONDecoder().decode([ChatMessage].self, from: data)
    }

    func sendMessage(_ message: String) async throws -> ChatMessage {
        let data = try await request("/ai-chat", method: "POST",
                                     body: ["message": message])
        return try JSONDecoder().decode(ChatMessage.self, from: data)
    }
}
