import Foundation

// MARK: - Auth
struct AuthResponse: Codable {
    let token: String
}

// MARK: - User
struct User: Codable {
    let user_id: Int
    let email: String
    let weight: Double?
    let height: Double?
    let age: Int?
    let sex: String?
}

// MARK: - Exercise
struct Exercise: Codable, Identifiable, Hashable {
    let exercise_id: Int
    let exercise_name: String
    var id: Int { exercise_id }
}

// MARK: - Session
struct WorkoutSession: Codable, Identifiable {
    let session_id: Int
    let date: String
    let notes: String?
    let user_id: Int
    var id: Int { session_id }

    var formattedDate: String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        let display = DateFormatter()
        display.dateStyle = .medium
        if let d = parser.date(from: date) { return display.string(from: d) }
        return date
    }

    var dayOfWeek: String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        let display = DateFormatter()
        display.dateFormat = "EEEE"
        if let d = parser.date(from: date) { return display.string(from: d) }
        return ""
    }
}

// MARK: - Entry
struct Entry: Codable, Identifiable {
    let entry_id: Int
    let set_number: Int
    let reps: Int
    let weight: Double
    let session_id: Int
    let exercise_id: Int
    var id: Int { entry_id }
}

// MARK: - Chat
struct ChatMessage: Codable, Identifiable {
    let message_id: Int
    let message: String
    let role: String
    let user_id: Int
    var id: Int { message_id }
}

// MARK: - API Error
struct APIError: Codable {
    let error: String
}
