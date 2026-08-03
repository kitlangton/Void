//
//  HealthKitService.swift
//  Void
//
//  Created by Kit Langton on 6/24/24.
//

import Foundation
import HealthKit

public struct Session: Identifiable {
  public let id = UUID()
  public let date: Date
  public let duration: TimeInterval
}

enum HealthKitPermission: CustomStringConvertible {
  case authorized
  case denied
  case notDetermined

  var description: String {
    switch self {
    case .authorized: return "Authorized"
    case .denied: return "Denied"
    case .notDetermined: return "Not Determined"
    }
  }
}

enum HealthKitServiceError: Error, LocalizedError {
  case mindfulTypeUnavailable
  case unknownError(String)
  case failedToCalculateStartDate

  var errorDescription: String? {
    switch self {
    case .mindfulTypeUnavailable:
      return "Mindful session type not available"
    case let .unknownError(message):
      return message
    case .failedToCalculateStartDate:
      return "Failed to calculate start date"
    }
  }
}

class HealthKitClientLive {
  private let healthStore = HKHealthStore()

  init() {}

  func requestAuthorization() async throws -> HealthKitPermission {
    guard HKHealthStore.isHealthDataAvailable() else {
      return .denied
    }

    guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else {
      throw HealthKitServiceError.mindfulTypeUnavailable
    }

    try await healthStore.requestAuthorization(toShare: [mindfulType], read: [mindfulType])
    return checkAuthorization()
  }

  func saveMindfulSession(startDate: Date, endDate: Date) async throws {
    guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else {
      throw HealthKitServiceError.mindfulTypeUnavailable
    }

    let mindfulSession = HKCategorySample(
      type: mindfulType,
      value: HKCategoryValue.notApplicable.rawValue,
      start: startDate,
      end: endDate
    )

    try await healthStore.save(mindfulSession)
  }

  func getDailyMindfulSessions() async throws -> [Session] {
    guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else {
      throw HealthKitServiceError.mindfulTypeUnavailable
    }

    let calendar = Calendar.current
    let now = Date()
    guard let startDate = calendar.date(byAdding: .day, value: -365, to: now) else {
      throw HealthKitServiceError.failedToCalculateStartDate
    }

    let predicate = HKQuery.predicateForSamples(
      withStart: startDate,
      end: now,
      options: .strictStartDate
    )
    let sortDescriptor = NSSortDescriptor(
      key: HKSampleSortIdentifierEndDate,
      ascending: false
    )

    return try await withCheckedThrowingContinuation { continuation in
      let query = HKSampleQuery(
        sampleType: mindfulType,
        predicate: predicate,
        limit: HKObjectQueryNoLimit,
        sortDescriptors: [sortDescriptor]
      ) { _, samples, error in
        if let error = error {
          continuation.resume(throwing: error)
          return
        }

        guard let samples = samples as? [HKCategorySample] else {
          continuation.resume(
            throwing: HealthKitServiceError.unknownError(
              "Failed to cast samples to [HKCategorySample]"
            )
          )
          return
        }

        let groupedSessions = Dictionary(grouping: samples) {
          calendar.startOfDay(for: $0.startDate)
        }

        let sessions = groupedSessions.map { date, samples in
          let totalDuration = samples.reduce(0) {
            $0 + $1.endDate.timeIntervalSince($1.startDate)
          }
          return Session(date: date, duration: totalDuration)
        }.sorted { $0.date > $1.date }

        continuation.resume(returning: sessions)
      }

      healthStore.execute(query)
    }
  }

  func getSessions(on day: Date) async throws -> [MindfulSessionSample] {
    guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else {
      throw HealthKitServiceError.mindfulTypeUnavailable
    }

    let calendar = Calendar.current
    let startOfDay = calendar.startOfDay(for: day)
    let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)
    let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay)
    let samples = try await querySamples(type: mindfulType, predicate: predicate)
    let ownSource = HKSource.default()

    return samples.map { sample in
      MindfulSessionSample(
        id: sample.uuid,
        startDate: sample.startDate,
        endDate: sample.endDate,
        isEditable: sample.sourceRevision.source == ownSource
      )
    }
    .sorted { $0.startDate < $1.startDate }
  }

  func deleteMindfulSession(uuid: UUID) async throws {
    guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else {
      throw HealthKitServiceError.mindfulTypeUnavailable
    }

    let predicate = HKQuery.predicateForObject(with: uuid)
    let samples = try await querySamples(type: mindfulType, predicate: predicate)
    guard let sample = samples.first else { return }
    try await healthStore.delete(sample)
  }

  func updateMindfulSession(uuid: UUID, startDate: Date, endDate: Date) async throws {
    guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else {
      throw HealthKitServiceError.mindfulTypeUnavailable
    }

    let replacement = HKCategorySample(
      type: mindfulType,
      value: HKCategoryValue.notApplicable.rawValue,
      start: startDate,
      end: endDate
    )
    try await healthStore.save(replacement)

    do {
      try await deleteMindfulSession(uuid: uuid)
    } catch {
      try? await healthStore.delete(replacement)
      throw error
    }
  }

  private func querySamples(
    type: HKSampleType,
    predicate: NSPredicate
  ) async throws -> [HKSample] {
    try await withCheckedThrowingContinuation { continuation in
      let query = HKSampleQuery(
        sampleType: type,
        predicate: predicate,
        limit: HKObjectQueryNoLimit,
        sortDescriptors: [
          NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true),
        ]
      ) { _, samples, error in
        if let error = error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(returning: samples ?? [])
        }
      }

      healthStore.execute(query)
    }
  }

  func checkAuthorization() -> HealthKitPermission {
    guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else {
      fatalError("Failed to create mindful type")
    }

    let status = healthStore.authorizationStatus(for: mindfulType)
    print("Authorization status: \(status)")
    switch status {
    case .sharingAuthorized: return .authorized
    case .sharingDenied: return .denied
    default: return .notDetermined
    }
  }
}
