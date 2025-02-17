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
}

struct MindfulSession: Sendable {
  let startDate: Date
  let endDate: Date
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
      getDailyMindfulSessions: { [] }
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
      getDailyMindfulSessions: { [] }
    )
  }
}

extension DependencyValues {
  var healthKitClient: HealthKitClient {
    get { self[HealthKitClient.self] }
    set { self[HealthKitClient.self] = newValue }
  }
}
