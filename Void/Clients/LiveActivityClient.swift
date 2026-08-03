import ActivityKit
import ComposableArchitecture
import Foundation

/// Mirrors the current meditation session onto a Live Activity
/// (lock screen + Dynamic Island). Syncing `nil` ends the activity.
@DependencyClient
struct LiveActivityClient: Sendable {
  var sync: @Sendable (ElapsedTime?) async -> Void
}

extension LiveActivityClient: DependencyKey {
  static var liveValue: LiveActivityClient {
    let manager = LiveActivityManager()
    return LiveActivityClient(
      sync: { await manager.sync($0) }
    )
  }

  static var testValue: LiveActivityClient {
    LiveActivityClient(sync: { _ in })
  }
}

extension DependencyValues {
  var liveActivityClient: LiveActivityClient {
    get { self[LiveActivityClient.self] }
    set { self[LiveActivityClient.self] = newValue }
  }
}

private extension MeditationActivityAttributes.ContentState {
  init(elapsedTime: ElapsedTime, now: Date) {
    if elapsedTime.isPaused {
      self.init(startDate: now, pausedElapsedSeconds: elapsedTime.secondsElapsed(now: now))
    } else {
      self.init(startDate: now.addingTimeInterval(-elapsedTime.elapsed(now: now)), pausedElapsedSeconds: nil)
    }
  }
}

private actor LiveActivityManager {
  private func currentActivity() -> Activity<MeditationActivityAttributes>? {
    Activity<MeditationActivityAttributes>.activities.first
  }

  func sync(_ elapsedTime: ElapsedTime?) async {
    guard let elapsedTime else {
      await endAll()
      return
    }

    let content = ActivityContent(
      state: MeditationActivityAttributes.ContentState(elapsedTime: elapsedTime, now: Date()),
      staleDate: nil
    )

    if let activity = currentActivity() {
      await activity.update(content)
    } else {
      guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
      do {
        _ = try Activity.request(
          attributes: MeditationActivityAttributes(),
          content: content
        )
      } catch {
        print("Failed to start live activity: \(error)")
      }
    }
  }

  private func endAll() async {
    for activity in Activity<MeditationActivityAttributes>.activities {
      await activity.end(nil, dismissalPolicy: .immediate)
    }
  }
}
