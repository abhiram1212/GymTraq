import Foundation

// Weight/height are always stored in the DB as kg / cm. These preferences only
// change how values are displayed and entered; conversion happens at the edges.

enum WeightUnit: String, CaseIterable, Identifiable {
    case kg, lb
    var id: String { rawValue }
    var label: String { self == .kg ? "kg" : "lb" }

    func fromKg(_ kg: Double) -> Double { self == .kg ? kg : kg * 2.2046226218 }
    func toKg(_ value: Double) -> Double { self == .kg ? value : value / 2.2046226218 }
}

enum HeightUnit: String, CaseIterable, Identifiable {
    case cm
    case ftin
    var id: String { rawValue }
    var label: String { self == .cm ? "cm" : "ft / in" }

    /// cm → (feet, inches) with inches rounded to the nearest whole.
    func feetInches(fromCm cm: Double) -> (feet: Int, inches: Int) {
        let totalInches = (cm / 2.54).rounded()
        return (Int(totalInches) / 12, Int(totalInches) % 12)
    }

    func cm(fromFeet feet: Int, inches: Int) -> Double {
        Double(feet * 12 + inches) * 2.54
    }
}

@Observable
class UnitSettings {
    static let shared = UnitSettings()

    var weight: WeightUnit {
        didSet { UserDefaults.standard.set(weight.rawValue, forKey: "unit_weight") }
    }
    var height: HeightUnit {
        didSet { UserDefaults.standard.set(height.rawValue, forKey: "unit_height") }
    }

    private init() {
        weight = UserDefaults.standard.string(forKey: "unit_weight").flatMap(WeightUnit.init) ?? .kg
        height = UserDefaults.standard.string(forKey: "unit_height").flatMap(HeightUnit.init) ?? .cm
    }

    // MARK: - Display helpers

    /// A stored-kg value formatted in the user's chosen unit, e.g. "176 lb".
    func weightLabel(fromKg kg: Double) -> String {
        "\(trim(weight.fromKg(kg))) \(weight.label)"
    }

    /// A stored-cm value formatted in the user's chosen unit, e.g. "5'11\"".
    func heightLabel(fromCm cm: Double) -> String {
        switch height {
        case .cm:
            return "\(trim(cm)) cm"
        case .ftin:
            let (f, i) = height.feetInches(fromCm: cm)
            return "\(f)'\(i)\""
        }
    }

    func trim(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}
