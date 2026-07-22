import SwiftUI
import Charts

// MARK: - Progress tab: weekly volume, per-exercise progression, personal records

struct ProgressTabView: View {
    var vm: SessionsViewModel
    @State private var selectedExerciseId: Int?

    private static let ymd: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Progress")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("\(vm.sessions.count) sessions tracked")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 14)

            if vm.isLoading {
                Spacer()
                ProgressView().tint(.white)
                Spacer()
            } else if vm.allEntries.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 50))
                        .foregroundStyle(.white.opacity(0.15))
                    Text("No data yet")
                        .foregroundStyle(.white.opacity(0.35))
                    Text("Log a few workouts and your charts appear here")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.25))
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        weeklyVolumeCard
                        progressionCard
                        prCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
                .scrollIndicators(.hidden)
                .refreshable { await vm.load() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background { AnimatedBackground() }
        .task { await vm.loadIfNeeded() }
        .colorScheme(.dark)
    }

    // MARK: - Weekly volume

    private struct WeekVolume: Identifiable {
        let id: Date
        let volume: Double
    }

    private var weeklyVolume: [WeekVolume] {
        let cal = Calendar.current
        let dateBySession = Dictionary(uniqueKeysWithValues: vm.sessions.map { ($0.session_id, $0.date) })
        var totals: [Date: Double] = [:]
        for e in vm.allEntries {
            guard let ds = dateBySession[e.session_id],
                  let d = Self.ymd.date(from: ds),
                  let week = cal.dateInterval(of: .weekOfYear, for: d)?.start else { continue }
            totals[week, default: 0] += e.weight * Double(e.reps)
        }
        guard let currentWeek = cal.dateInterval(of: .weekOfYear, for: Date())?.start else { return [] }
        return (0..<8).compactMap { offset in
            guard let week = cal.date(byAdding: .weekOfYear, value: -offset, to: currentWeek) else { return nil }
            return WeekVolume(id: week, volume: totals[week] ?? 0)
        }.reversed()
    }

    private var weeklyVolumeCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                cardHeader("Weekly Volume", icon: "chart.bar.fill", detail: "kg lifted · last 8 weeks")

                Chart(weeklyVolume) { week in
                    BarMark(
                        x: .value("Week", week.id, unit: .weekOfYear),
                        y: .value("Volume", week.volume)
                    )
                    .foregroundStyle(Color.appAccent.gradient)
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .weekOfYear)) {
                        AxisValueLabel(format: .dateTime.day().month(), centered: true)
                            .foregroundStyle(.white.opacity(0.35))
                            .font(.system(size: 9))
                    }
                }
                .chartYAxis {
                    AxisMarks {
                        AxisGridLine().foregroundStyle(.white.opacity(0.08))
                        AxisValueLabel().foregroundStyle(.white.opacity(0.35))
                    }
                }
                .frame(height: 160)
            }
        }
    }

    // MARK: - Exercise progression

    private struct ProgressPoint: Identifiable {
        let id: Date
        let weight: Double
    }

    private var exercisesWithData: [Exercise] {
        let ids = Set(vm.allEntries.map(\.exercise_id))
        return vm.allExercises.filter { ids.contains($0.exercise_id) }
    }

    private var effectiveExerciseId: Int? {
        if let selected = selectedExerciseId,
           exercisesWithData.contains(where: { $0.exercise_id == selected }) {
            return selected
        }
        // Default to the most-logged exercise
        return Dictionary(grouping: vm.allEntries, by: \.exercise_id)
            .max { $0.value.count < $1.value.count }?.key
    }

    private var progressionPoints: [ProgressPoint] {
        guard let exId = effectiveExerciseId else { return [] }
        let dateBySession = Dictionary(uniqueKeysWithValues: vm.sessions.map { ($0.session_id, $0.date) })
        let bySession = Dictionary(grouping: vm.allEntries.filter { $0.exercise_id == exId },
                                   by: \.session_id)
        return bySession.compactMap { sid, sets -> ProgressPoint? in
            guard let ds = dateBySession[sid],
                  let d = Self.ymd.date(from: ds),
                  let top = sets.map(\.weight).max() else { return nil }
            return ProgressPoint(id: d, weight: top)
        }
        .sorted { $0.id < $1.id }
    }

    private var progressionCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    cardHeader("Strength Trend", icon: "chart.line.uptrend.xyaxis", detail: "top set per session")
                    Menu {
                        ForEach(exercisesWithData) { ex in
                            Button(ex.exercise_name) { selectedExerciseId = ex.exercise_id }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(exercisesWithData.first { $0.exercise_id == effectiveExerciseId }?.exercise_name ?? "Pick")
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundStyle(Color.appAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.appAccent.opacity(0.12), in: Capsule())
                    }
                }

                if progressionPoints.count < 2 {
                    Text("Log this exercise in at least two sessions to see a trend.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.35))
                        .frame(maxWidth: .infinity, minHeight: 100)
                } else {
                    Chart(progressionPoints) { point in
                        LineMark(
                            x: .value("Date", point.id),
                            y: .value("Top set", point.weight)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Color.appAccent)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))

                        PointMark(
                            x: .value("Date", point.id),
                            y: .value("Top set", point.weight)
                        )
                        .foregroundStyle(Color.appAccent)

                        AreaMark(
                            x: .value("Date", point.id),
                            y: .value("Top set", point.weight)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(colors: [Color.appAccent.opacity(0.25), .clear],
                                           startPoint: .top, endPoint: .bottom)
                        )
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .chartXAxis {
                        AxisMarks {
                            AxisValueLabel(format: .dateTime.day().month())
                                .foregroundStyle(.white.opacity(0.35))
                                .font(.system(size: 9))
                        }
                    }
                    .chartYAxis {
                        AxisMarks {
                            AxisGridLine().foregroundStyle(.white.opacity(0.08))
                            AxisValueLabel().foregroundStyle(.white.opacity(0.35))
                        }
                    }
                    .frame(height: 160)
                }
            }
        }
    }

    // MARK: - Personal records

    private struct PRRow: Identifiable {
        let id: Int
        let name: String
        let weight: Double
        let reps: Int
    }

    private var personalRecords: [PRRow] {
        let nameById = Dictionary(uniqueKeysWithValues: vm.allExercises.map { ($0.exercise_id, $0.exercise_name) })
        return Dictionary(grouping: vm.allEntries, by: \.exercise_id)
            .compactMap { exId, sets -> PRRow? in
                guard let best = sets.max(by: { ($0.weight, $0.reps) < ($1.weight, $1.reps) }) else { return nil }
                return PRRow(id: exId, name: nameById[exId] ?? "Unknown",
                             weight: best.weight, reps: best.reps)
            }
            .sorted { $0.weight > $1.weight }
            .prefix(5)
            .map { $0 }
    }

    private var prCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                cardHeader("Personal Records", icon: "trophy.fill", detail: "heaviest sets")

                ForEach(Array(personalRecords.enumerated()), id: \.element.id) { index, pr in
                    HStack(spacing: 12) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(index == 0 ? .yellow : .white.opacity(0.25))
                            .frame(width: 20)
                        Text(pr.name)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Spacer()
                        Text("\(formatWeight(pr.weight)) kg × \(pr.reps)")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(index == 0 ? Color.appAccent : .white.opacity(0.8))
                    }
                    .padding(.vertical, 6)
                    if index < personalRecords.count - 1 {
                        Divider().background(.white.opacity(0.06))
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func cardHeader(_ title: String, icon: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.appAccent)
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", w) : String(format: "%.1f", w)
    }
}
