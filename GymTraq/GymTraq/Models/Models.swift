import Foundation
import SwiftUI

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
    let muscle_group: String?
    var id: Int { exercise_id }
}

// MARK: - Muscle Group

enum MuscleGroup: String, CaseIterable {
    case chest     = "Chest"
    case back      = "Back"
    case legs      = "Legs"
    case shoulders = "Shoulders"
    case biceps    = "Biceps"
    case triceps   = "Triceps"
    case core      = "Core"
    case other     = "Other"

    var color: Color {
        switch self {
        case .chest:     return Color(red: 0.25, green: 0.6,  blue: 1.0)
        case .back:      return Color(red: 0.6,  green: 0.3,  blue: 1.0)
        case .legs:      return Color(red: 0.2,  green: 0.85, blue: 0.55)
        case .shoulders: return Color(red: 1.0,  green: 0.6,  blue: 0.2)
        case .biceps:    return Color(red: 1.0,  green: 0.85, blue: 0.2)
        case .triceps:   return Color(red: 1.0,  green: 0.35, blue: 0.35)
        case .core:      return Color(red: 0.2,  green: 0.9,  blue: 0.9)
        case .other:     return .white.opacity(0.45)
        }
    }
}

func muscleGroup(for exercise: Exercise) -> MuscleGroup {
    if let mg = exercise.muscle_group, let group = MuscleGroup(rawValue: mg) { return group }
    return muscleGroupByKeyword(exercise.exercise_name)
}

private func muscleGroupByKeyword(_ name: String) -> MuscleGroup {
    let n = name.lowercased()
    if n.contains("bench") || n.contains("chest") || n.contains("fly") || n.contains("flye") ||
       n.contains("pec") || n.contains("push-up") || n.contains("push up") || n.contains("pushup") ||
       n.contains("cable cross") { return .chest }
    if n.contains("squat") || n.contains("lunge") || n.contains("calf") || n.contains("quad") ||
       n.contains("hamstring") || n.contains("glute") || n.contains("hip thrust") ||
       n.contains("rdl") || n.contains("romanian") || n.contains("hack") ||
       n.contains("leg press") || n.contains("leg curl") || n.contains("leg extension") ||
       n.contains("step up") || n.contains("step-up") || n.contains("bulgarian") ||
       n.contains("leg raise") { return .legs }
    if n.contains("row") || n.contains("pulldown") || n.contains("pull-up") ||
       n.contains("pull up") || n.contains("pullup") || n.contains("lat ") ||
       n.contains("deadlift") || n.contains("back") || n.contains("chin") ||
       n.contains("t-bar") || n.contains("hyperextension") || n.contains("shrug") { return .back }
    if n.contains("tricep") || n.contains("skull") || n.contains("pushdown") ||
       n.contains("close grip") || n.contains("overhead tricep") || n.contains("kickback") ||
       n.contains("dip") { return .triceps }
    if n.contains("shoulder") || n.contains("delt") || n.contains("lateral raise") ||
       n.contains("front raise") || n.contains("overhead press") || n.contains("military") ||
       n.contains("arnold") || n.contains("upright") || n.contains("ohp") { return .shoulders }
    if n.contains("bicep") || n.contains("curl") || n.contains("hammer") ||
       n.contains("preacher") || n.contains("concentration") { return .biceps }
    if n.contains("plank") || n.contains("crunch") || n.contains("sit-up") ||
       n.contains("sit up") || n.contains("situp") || n.contains(" ab ") || n.contains("abs") ||
       n.contains("oblique") || n.contains("russian twist") || n.contains("hollow") { return .core }
    return .other
}

// MARK: - Session
struct WorkoutSession: Codable, Identifiable {
    let session_id: Int
    let date: String
    let notes: String?
    let name: String?
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
