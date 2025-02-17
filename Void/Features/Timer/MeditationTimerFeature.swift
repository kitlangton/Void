import ComposableArchitecture
import SwiftUI

@Reducer
struct MeditationTimerFeature {
  @ObservableState
  struct State {
    @Shared var meditationState: MeditationState
    @Shared(.settings) var settings: VoidSettings
    @Shared(.expandedSection) var expandedSection: SettingSection?
    var now: Date

    var elapsedSeconds: Int {
      meditationState.secondsElapsed(now: now)
    }

    var isPaused: Bool {
      meditationState.isPaused
    }

    var isPlaying: Bool {
      !isPaused
    }

    var remainingTime: Int? {
      settings.durationSeconds.map { $0 - elapsedSeconds }
    }

    /// Returns true if the elapsed seconds has changed
    mutating func updateNow(to now: Date) -> Int? {
      let prevSecondsElapsed = meditationState.secondsElapsed(now: self.now)
      self.now = now
      let newSecondsElapsed = meditationState.secondsElapsed(now: now)
      return newSecondsElapsed > prevSecondsElapsed ? newSecondsElapsed : nil
    }
  }

  enum Action: Equatable, Sendable {
    case start
    case pausePlay
    case tick
    case appDidBecomeActive
    case delegate(Delegate)

    enum Delegate: Equatable {
      case timerCompleted
    }
  }

  @Dependency(\.continuousClock) var clock
  @Dependency(\.soundManager) var audioManager
  @Dependency(\.date) var date

  enum CancelID: Hashable {
    case timer
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .start:
        guard state.isPlaying else { return .none }
        let elapsedTime = state.meditationState.elapsedTime
        return .run { send in
          await startTimer(elapsedTime: elapsedTime, send: send)
        }.cancellable(id: CancelID.timer, cancelInFlight: true)

      case .pausePlay:
        let now = date.now
        state.now = now
        if state.meditationState.elapsedTime.isPaused {
          state.$meditationState.elapsedTime.withLock { $0.resume(now: now) }
          return .none
        } else {
          state.$meditationState.elapsedTime.withLock { $0.pause(now: now) }
          return .cancel(id: CancelID.timer)
        }

      case .tick:
        return handleTick(state: &state)

      case .appDidBecomeActive, .delegate:
        return .none
      }
    }
  }

  private func handleTick(state: inout State) -> Effect<Action> {
    guard let secondsElapsed = state.updateNow(to: date.now) else {
      return .none
    }

    /// If there's a max duration, and we've reached it, we need to stop the timer and play the finish sound
    if let durationSeconds = state.settings.durationSeconds,
       secondsElapsed >= durationSeconds
    {
      Task {
        await audioManager.play(.completionBell)
      }
      return .send(.delegate(.timerCompleted), animation: .spring)
    }

    /// if current seconds is a multiple of settings.intervalMinutes, we need to play a chime sound
    if let intervalSeconds = state.settings.intervalSeconds,
       intervalSeconds > 0,
       secondsElapsed.isMultiple(of: intervalSeconds)
    {
      Task {
        await audioManager.play(.intervalBell)
      }
      return .none
    }

    return .none
  }

  private func startTimer(
    elapsedTime: ElapsedTime,
    send: Send<Action>
  ) async {
    print("starting timer")
    var seconds = elapsedTime.secondsElapsed(now: date.now)
    for await _ in clock.timer(interval: .milliseconds(100)) {
      let now = date.now
      let newSeconds = elapsedTime.secondsElapsed(now: now)
      let newSecondsInt = Int(newSeconds)

      if newSecondsInt != seconds {
        seconds = newSecondsInt
        await send(.tick)
      }
    }
    print("timer completed")
  }
}
