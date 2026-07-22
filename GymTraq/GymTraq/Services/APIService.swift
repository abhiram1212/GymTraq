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
    private let baseURL = "http://192.168.0.206:3000"

    // URLSession.shared waits 60s per request — far too long for a snappy UI.
    // Fail fast so error states show within seconds when the server is unreachable.
    private let urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()

    private static let tokenKey = "gymtraq_token"

    // Stored property so @Observable tracks changes and triggers SwiftUI re-renders.
    // Persisted in the Keychain (not UserDefaults) so the JWT isn't stored in plaintext.
    var token: String? {
        didSet {
            if let token {
                KeychainHelper.save(token, for: Self.tokenKey)
            } else {
                KeychainHelper.delete(Self.tokenKey)
            }
        }
    }

    private init() {
        // Rehydrate from the Keychain, but reject an already-expired token —
        // otherwise the app flashes Home and immediately 401s back to login
        if let stored = KeychainHelper.read(Self.tokenKey), !Self.isExpired(stored) {
            self.token = stored
        } else {
            self.token = nil
            KeychainHelper.delete(Self.tokenKey) // didSet doesn't fire in init
        }
    }

    var userId: Int? {
        guard let token else { return nil }
        return Self.decodePayload(token)?["user_id"] as? Int
    }

    var isAuthenticated: Bool { token != nil }

    func logout() { token = nil }

    // MARK: - JWT decode (client-side, verification done by server)
    private static func decodePayload(_ token: String) -> [String: Any]? {
        let parts = token.components(separatedBy: ".")
        guard parts.count == 3 else { return nil }
        var b64 = parts[1]
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let rem = b64.count % 4
        if rem > 0 { b64 += String(repeating: "=", count: 4 - rem) }
        guard let data = Data(base64Encoded: b64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json
    }

    private static func isExpired(_ token: String) -> Bool {
        guard let exp = decodePayload(token)?["exp"] as? Double else { return false }
        return Date(timeIntervalSince1970: exp) <= Date()
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
        let (data, response) = try await urlSession.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIServiceError.badResponse }
        guard (200...299).contains(http.statusCode) else {
            // Token rejected (expired or invalid) — clear it so the app routes back to login
            // instead of leaving the user stuck on screens where every request 401s.
            if http.statusCode == 401, requiresAuth, token != nil {
                await MainActor.run { logout() }
                throw APIServiceError.serverError("Session expired. Please sign in again.")
            }
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
        // Send every field explicitly — NSNull means "clear this value".
        // The backend patches only the keys present, so nothing is wiped by accident.
        let body: [String: Any] = [
            "weight": weight ?? NSNull(),
            "height": height ?? NSNull(),
            "age":    age    ?? NSNull(),
            "sex":    sex    ?? NSNull(),
        ]
        let data = try await request("/users/\(id)", method: "PUT", body: body)
        return try JSONDecoder().decode(User.self, from: data)
    }

    func updateProfilePic(id: Int, base64: String) async throws -> User {
        // Patch semantics server-side: only profile_pic changes
        let data = try await request("/users/\(id)", method: "PUT", body: ["profile_pic": base64])
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

    func updateExercise(id: Int, name: String, muscleGroup: String?) async throws -> Exercise {
        let body: [String: Any] = [
            "exercise_name": name,
            "muscle_group": muscleGroup ?? NSNull(),
        ]
        let data = try await request("/exercises/\(id)", method: "PUT", body: body)
        return try JSONDecoder().decode(Exercise.self, from: data)
    }

    func deleteExercise(id: Int) async throws {
        _ = try await request("/exercises/\(id)", method: "DELETE")
    }

    // Step 1: server emails a 6-digit code (via Resend)
    func requestPasswordReset(email: String) async throws {
        _ = try await request("/users/forgot-password", method: "POST",
                              body: ["email": email],
                              requiresAuth: false)
    }

    // Step 2: verify code + set new password
    func resetPassword(email: String, code: String, newPassword: String) async throws {
        _ = try await request("/users/reset-password", method: "POST",
                              body: ["email": email, "code": code, "newPassword": newPassword],
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
        // Always send name (NSNull clears it) — matches notes semantics so users can clear a session name
        body["name"] = name ?? NSNull()
        let data = try await request("/sessions/\(id)", method: "PUT", body: body)
        return try JSONDecoder().decode(WorkoutSession.self, from: data)
    }

    func getAllEntries() async throws -> [Entry] {
        let data = try await request("/entries")
        return try JSONDecoder().decode([Entry].self, from: data)
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
