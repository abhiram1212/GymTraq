import SwiftUI

/// Month grid with a lime dot on days that have workouts. Tap a day to select it;
/// arrows change month; Today jumps back. Sunday-first.
struct WorkoutCalendarView: View {
    let workoutDates: Set<String>      // "yyyy-MM-dd" of days with sessions
    @Binding var selectedDate: Date
    @Binding var month: Date           // any date within the displayed month

    private let cal = Calendar.current
    private static let ymd: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.calendar = .current; return f
    }()
    private static let monthTitle: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; return f
    }()

    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        GlassCard {
            VStack(spacing: 14) {
                // Month nav
                HStack {
                    Text(Self.monthTitle.string(from: month))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Button { changeMonth(-1) } label: { navChevron("chevron.left") }
                    Button { jumpToToday() } label: {
                        Text("Today")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.appAccent)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Color.appAccent.opacity(0.12), in: Capsule())
                    }
                    Button { changeMonth(1) } label: { navChevron("chevron.right") }
                }

                // Weekday header
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, s in
                        Text(s)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                }

                // Day grid
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(Array(gridDays.enumerated()), id: \.offset) { _, day in
                        if let day { dayCell(day) } else { Color.clear.frame(height: 38) }
                    }
                }
            }
        }
    }

    // MARK: - Day cell

    private func dayCell(_ day: Date) -> some View {
        let isSelected = cal.isDate(day, inSameDayAs: selectedDate)
        let isToday = cal.isDateInToday(day)
        let hasWorkout = workoutDates.contains(Self.ymd.string(from: day))

        return Button {
            withAnimation(.spring(duration: 0.25)) { selectedDate = day }
        } label: {
            VStack(spacing: 3) {
                Text("\(cal.component(.day, from: day))")
                    .font(.system(size: 15, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundStyle(isSelected ? .black : .white.opacity(0.85))
                Circle()
                    .fill(hasWorkout ? (isSelected ? Color.black.opacity(0.55) : Color.appAccent) : .clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background {
                if isSelected {
                    Circle().fill(Color.appAccent).frame(width: 38, height: 38)
                } else if isToday {
                    Circle().stroke(Color.appAccent.opacity(0.6), lineWidth: 1.5)
                        .frame(width: 38, height: 38)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func navChevron(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white.opacity(0.6))
            .frame(width: 30, height: 30)
            .background(Color.appCardElevated, in: Circle())
    }

    // MARK: - Grid model

    /// Leading nils pad the first week so day 1 lands under its weekday.
    private var gridDays: [Date?] {
        guard let first = cal.date(from: cal.dateComponents([.year, .month], from: month)),
              let range = cal.range(of: .day, in: .month, for: first) else { return [] }
        let leading = cal.component(.weekday, from: first) - 1 // Sunday=1
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for d in range {
            cells.append(cal.date(byAdding: .day, value: d - 1, to: first))
        }
        return cells
    }

    private func changeMonth(_ delta: Int) {
        if let m = cal.date(byAdding: .month, value: delta, to: month) {
            withAnimation(.spring(duration: 0.3)) { month = m }
        }
    }

    private func jumpToToday() {
        withAnimation(.spring(duration: 0.3)) {
            month = Date()
            selectedDate = Date()
        }
    }
}
