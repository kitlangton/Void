//
//  HealthKitClient.swift
//  Void
//
//  Created by Kit Langton on 12/1/24.
//

import ComposableArchitecture
import Foundation

@DependencyClient
struct HealthKitClient: Sendable {
  var isAuthorized: @Sendable () -> Bool = { false }
  var requestAuthorization: @Sendable () async throws -> HealthKitPermission
  var saveMindfulnessSession: @Sendable (_ mindfulSession: MindfulSession) async throws -> Void
  var getDailyMindfulSessions: @Sendable () async throws -> [Session]
  var getSessions: @Sendable (_ day: Date) async throws -> [MindfulSessionSample]
  var deleteMindfulSession: @Sendable (_ id: UUID) async throws -> Void
  var updateMindfulSession: @Sendable (_ id: UUID, _ mindfulSession: MindfulSession) async throws -> Void
}

struct MindfulSession: Sendable {
  let startDate: Date
  let endDate: Date
}

/// One individual mindful session sample from HealthKit.
struct MindfulSessionSample: Equatable, Identifiable, Sendable {
  let id: UUID
  let startDate: Date
  let endDate: Date
  /// Only samples written by Void can be edited or deleted.
  let isEditable: Bool

  var durationSeconds: Int {
    Int(endDate.timeIntervalSince(startDate))
  }

  /// Whole minutes, floored for compact row display.
  var minutes: Int {
    durationSeconds / 60
  }
}

extension HealthKitClient: DependencyKey {
  static var testValue: HealthKitClient {
    let isAuthorized = LockIsolated(false)
    return Self(
      isAuthorized: { isAuthorized.value },
      requestAuthorization: {
        isAuthorized.withValue { $0 = true }
        return .authorized
      },
      saveMindfulnessSession: { _ in
        // no-op
      },
      getDailyMindfulSessions: { [] },
      getSessions: { _ in [] },
      deleteMindfulSession: { _ in },
      updateMindfulSession: { _, _ in }
    )
  }

  static var liveValue: HealthKitClient {
    let live = HealthKitClientLive()
    return Self(
      isAuthorized: {
        live.checkAuthorization() == .authorized
      },
      requestAuthorization: {
        try await live.requestAuthorization()
      },
      saveMindfulnessSession: { session in
        try await live.saveMindfulSession(
          startDate: session.startDate,
          endDate: session.endDate
        )
      },
      getDailyMindfulSessions: {
        try await live.getDailyMindfulSessions()
      },
      getSessions: { day in
        try await live.getSessions(on: day)
      },
      deleteMindfulSession: { id in
        try await live.deleteMindfulSession(uuid: id)
      },
      updateMindfulSession: { id, session in
        try await live.updateMindfulSession(
          uuid: id,
          startDate: session.startDate,
          endDate: session.endDate
        )
      }
    )
  }

  static var previewValue: HealthKitClient {
    Self(
      isAuthorized: {
        true
      },
      requestAuthorization: {
        .authorized
      },
      saveMindfulnessSession: { _ in
        // no-op
      },
      getDailyMindfulSessions: { [] },
      getSessions: { _ in sampleTodaysSessions() },
      deleteMindfulSession: { _ in },
      updateMindfulSession: { _, _ in }
    )
  }
}

func sampleTodaysSessions() -> [MindfulSessionSample] {
  let calendar = Calendar.current
  let today = calendar.startOfDay(for: Date())

  func at(hour: Int, minute: Int, minutes: Int) -> MindfulSessionSample {
    let start = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today) ?? today
    return MindfulSessionSample(
      id: UUID(),
      startDate: start,
      endDate: start.addingTimeInterval(Double(minutes) * 60),
      isEditable: true
    )
  }

  return [
    at(hour: 7, minute: 12, minutes: 10),
    at(hour: 12, minute: 40, minutes: 2),
  ]
}

extension DependencyValues {
  var healthKitClient: HealthKitClient {
    get { self[HealthKitClient.self] }
    set { self[HealthKitClient.self] = newValue }
  }
}
