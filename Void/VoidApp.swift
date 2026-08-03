//

//  VoidApp.swift
//  Void
//
//  Created by Kit Langton on 6/23/24.
//

import ComposableArchitecture
import Inject
import SwiftData
import SwiftUI

@main
struct VoidApp: App {
  static let initialState: HomeReducer.State = {
    var state = HomeReducer.State()

    if AppLaunchMode.screenshotEnabled {
      state.healthKitPermissionState = .granted
      state.stats.dailyStats = sampleDailyStats()

      if AppLaunchMode.screenshotPage == .timer || AppLaunchMode.screenshotPage == .intervals {
        let now = Date()
        state.$meditationState.withLock {
          $0 = MeditationState(now: now.addingTimeInterval(-67))
        }
        if let meditationState = Shared(state.$meditationState) {
          state.meditationTimer = MeditationTimerFeature.State(
            meditationState: meditationState,
            now: now
          )
        }

        if AppLaunchMode.screenshotPage == .intervals {
          state.settings.$expandedSection.withLock { $0 = .intervals }
        }
      }
    }

    return state
  }()

  static let store =
    Store(initialState: initialState) {
      HomeReducer()
    } withDependencies: {
      if isTesting || AppLaunchMode.screenshotEnabled {
        $0.defaultFileStorage = .inMemory
      }

      if AppLaunchMode.screenshotEnabled {
        $0.healthKitClient.isAuthorized = { true }
        $0.healthKitClient.getSessions = { _ in sampleTodaysSessions() }
        $0.statsClient.getDailyStats = {
          sampleDailyStats()
        }
      }
    }

  var body: some Scene {
    WindowGroup {
      if isTesting {
        EmptyView()
      } else {
        HomeView(store: VoidApp.store)
      }
    }
  }
}
