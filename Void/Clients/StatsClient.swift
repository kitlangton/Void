//
//  StatsClient.swift
//  Void
//
//  Created by Kit Langton on 12/1/24.
//

import ComposableArchitecture
import Foundation

// MARK: - StatsClient

@DependencyClient
struct StatsClient: Sendable {
  var getDailyStats: @Sendable () async throws -> DailyStats
  var getWeeklyStats: @Sendable () async throws -> [Double]
}

struct DailyStats: Equatable {
  let streak: Int
  let totalMinutesToday: Double
  let recentPracticeDays: [PracticeDay]
}

struct PracticeDay: Equatable, Identifiable, Sendable {
  let date: Date
  let minutes: Double
  let isInCurrentStreak: Bool

  var id: Date { date }
  var didMeditate: Bool { minutes > 0 }
}

extension StatsClient: DependencyKey {
  static var liveValue: StatsClient {
    let live = StatsClientLive()
    return StatsClient(
      getDailyStats: { try await live.getDailyStats() },
      getWeeklyStats: { try await live.getWeeklyStats() }
    )
  }

  static var previewValue: StatsClient {
    StatsClient(
      getDailyStats: {
        sampleDailyStats(totalMinutesToday: 10)
      },
      getWeeklyStats: { [10] }
    )
  }
}

extension DependencyValues {
  var statsClient: StatsClient {
    get { self[StatsClient.self] }
    set { self[StatsClient.self] = newValue }
  }
}

// MARK: - Live Implementation

struct StatsClientLive: Sendable {
  @Dependency(\.healthKitClient) var healthKitClient

  @Sendable
  func getDailyStats() async throws -> DailyStats {
    let sessions = try await healthKitClient.getDailyMindfulSessions()
    return DailyStats(
      streak: calculateStreak(from: sessions),
      totalMinutesToday: calculateTotalMinutesToday(from: sessions),
      recentPracticeDays: calculateRecentPracticeDays(from: sessions)
    )
  }

  @Sendable
  func getWeeklyStats() async throws -> [Double] {
    let sessions = try await healthKitClient.getDailyMindfulSessions()
    return calculateWeeklyStats(from: sessions)
  }

  // MARK: - Private Calculation Methods

  private func calculateTotalMinutesToday(from sessions: [Session]) -> Double {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    return sessions
      .filter { calendar.startOfDay(for: $0.date) == today }
      .reduce(0.0) { $0 + $1.duration / 60 }
  }

  private func calculateStreak(from sessions: [Session]) -> Int {
    calculateCurrentStreakDates(from: sessions).count
  }

  private func calculateCurrentStreakDates(from sessions: [Session]) -> Set<Date> {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())

    let sessionDates = Set(sessions.map { calendar.startOfDay(for: $0.date) })
    guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
      return sessionDates.contains(today) ? [today] : []
    }

    guard sessionDates.contains(today) || sessionDates.contains(yesterday) else {
      return []
    }

    var currentDate = sessionDates.contains(today) ? today : yesterday
    var streakDates: Set<Date> = [currentDate]

    while let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) {
      if sessionDates.contains(previousDay) {
        streakDates.insert(previousDay)
        currentDate = previousDay
      } else {
        break
      }
    }

    return streakDates
  }

  private func calculateRecentPracticeDays(from sessions: [Session], dayCount: Int = 42) -> [PracticeDay] {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let streakDates = calculateCurrentStreakDates(from: sessions)
    let minutesByDay = sessions.reduce(into: [Date: Double]()) { result, session in
      result[calendar.startOfDay(for: session.date)] = session.duration / 60
    }

    return (0 ..< dayCount).compactMap { offset in
      guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else {
        return nil
      }

      let day = calendar.startOfDay(for: date)
      return PracticeDay(
        date: day,
        minutes: minutesByDay[day] ?? 0,
        isInCurrentStreak: streakDates.contains(day)
      )
    }
  }

  private func calculateWeeklyStats(from sessions: [Session]) -> [Double] {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    var stats: [Double] = Array(repeating: 0, count: 52)

    for weekOffset in 0 ..< 52 {
      guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: today),
            let weekEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) else { continue }

      let weekMinutes = sessions
        .filter {
          let date = calendar.startOfDay(for: $0.date)
          return date >= weekStart && date < weekEnd
        }
        .reduce(0.0) { $0 + $1.duration / 60 }

      stats[weekOffset] = weekMinutes
    }

    return stats.reversed()
  }
}

/// Sample stats whose streak count always matches the highlighted days.
func sampleDailyStats(totalMinutesToday: Double = 12) -> DailyStats {
  let days = samplePracticeDays()
  return DailyStats(
    streak: days.count(where: \.isInCurrentStreak),
    totalMinutesToday: totalMinutesToday,
    recentPracticeDays: days
  )
}

func samplePracticeDays() -> [PracticeDay] {
  let calendar = Calendar.current
  let today = calendar.startOfDay(for: Date())

  /// A 14-day current streak, a rest day, then a looser earlier habit.
  let streakLength = 14
  let earlierPracticedOffsets: Set<Int> = [15, 16, 17, 19, 20, 22, 23, 24, 27, 29, 30, 33, 34, 38, 41]
  let sampleMinutes: [Double] = [12, 20, 10, 15, 30, 12, 25, 10, 18, 22, 15, 10, 20, 12]

  return (0 ..< 42).compactMap { offset in
    guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else {
      return nil
    }

    let isInStreak = offset < streakLength
    let practiced = isInStreak || earlierPracticedOffsets.contains(offset)

    return PracticeDay(
      date: date,
      minutes: practiced ? sampleMinutes[offset % sampleMinutes.count] : 0,
      isInCurrentStreak: isInStreak
    )
  }
}
