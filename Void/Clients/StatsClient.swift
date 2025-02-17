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
      getDailyStats: { .init(streak: 4, totalMinutesToday: 10) },
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
      totalMinutesToday: calculateTotalMinutesToday(from: sessions)
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
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())

    let sessionDates = Set(sessions.map { calendar.startOfDay(for: $0.date) })
    let hasTodaySession = sessionDates.contains(today)

    guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
      return hasTodaySession ? 1 : 0
    }

    var currentDate = hasTodaySession ? today : yesterday
    var streak = hasTodaySession ? 1 : 0

    while let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) {
      if sessionDates.contains(previousDay) {
        streak += 1
        currentDate = previousDay
      } else {
        break
      }
    }

    if !hasTodaySession && sessionDates.contains(yesterday) {
      streak += 1
    }

    return streak
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
