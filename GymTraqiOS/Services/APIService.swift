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

    var token: String? {
        get { UserDefaults.standard.string(forKey: "gymtraq_token") }
        set { UserDefaults.standard.set(newValue, forKey: "gymtraq_token") }
    }

    var userId: Int? {
        guard let token else { return nil }
        return decodeJWT(token)
    }

    var isAuthenticated: Bool { token != nil }

    func logout() { token = nil }

    // MARK: - JWT decode (client-side, no verification needed — server verifies)
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
    private func request(
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
        let resp = try await login(email: email, password: password)
        token = resp.token
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        let data = try await request("/users/login", method: "POST",
                                     body: ["email": email, "password": password],
                                     requiresAuth: false)
        let resp = try JSONDecoder().decode(AuthResponse.self, from: data)
        token = resp.token
        return resp
    }

    // MARK: - Sessions
    func getSessions() async throws -> [WorkoutSession] {
        let data = try await request("/sessions")
        return try JSONDecoder().decode([WorkoutSession].self, from: data)
    }

    func createSession(date: String, notes: String?) async throws -> WorkoutSession {
        var body: [String: Any] = ["date": date]
        if let notes { body["notes"] = notes }
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

    func createExercise(name: String) async throws -> Exercise {
        let data = try await request("/exercises", method: "POST",
                                     body: ["exercise_name": name])
        return try JSONDecoder().decode(Exercise.self, from: data)
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

    func deleteEntry(id: Int) async throws {
        _ = try await request("/entries/\(id)", method: "DELETE")
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
