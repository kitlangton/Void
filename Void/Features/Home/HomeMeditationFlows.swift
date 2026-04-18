import ComposableArchitecture
import Foundation
import SwiftUI

extension HomeReducer {
  func handleMeditationStateChange(state: inout State) {
    if state.meditationState == nil {
      // If meditation ended, clear the timer
      state.meditationTimer = nil
    } else if let meditationState = Shared(state.$meditationState),
              state.meditationTimer == nil
    {
      // If meditation started, initialize the timer
      state.meditationTimer = MeditationTimerFeature.State(
        meditationState: meditationState,
        now: date.now
      )
    }
  }
  
  func startMeditationFlow(_ state: inout State) -> Effect<Action> {
    state.$meditationState.withLock { $0 = MeditationState(now: date.now) }
    handleMeditationStateChange(state: &state)
    
    return .run { send in
      await audioManager.play(sound: .startBell)
      await send(.meditationTimer(.start))
    }
  }
  
  func stopMeditationFlow(_ state: inout State) -> Effect<Action> {
    guard let meditationState = state.meditationState else {
      return .none
    }
    
    let now = date.now
    let secondsElapsed = meditationState.elapsedTime.secondsElapsed(now: now)
    let startDate = now.addingTimeInterval(-Double(secondsElapsed))
    let shouldSaveMindfulnessSession = secondsElapsed > 10

    withAnimation(.spring) {
      state.$meditationState.withLock { $0 = nil }
      handleMeditationStateChange(state: &state)
    }

    return .merge(
      shouldSaveMindfulnessSession
        ? .run { _ in
          do {
            try await healthKitClient.saveMindfulnessSession(.init(startDate: startDate, endDate: now))
          } catch {
            print("Failed to save mindfulness session: \(error)")
          }
        }
        : .none,
      .run { _ in
        await audioManager.play(sound: .completionBell)
        await audioManager.setAmbient(nil)
      }
    )
  }
  
  func onAppearFlow(_ state: inout State) -> Effect<Action> {
    handleMeditationStateChange(state: &state)
    state.healthKitPermissionState = healthKitClient.isAuthorized() ? .granted : .denied
    
    // Play ambient sound if currently active
    return .run { [state] _ in
      await audioManager.preloadSounds()
      if let ambientSound = state.settings.settings.ambience, state.isActive {
        await audioManager.setAmbient(ambientSound)
      }
    }
  }
}
