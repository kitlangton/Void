import ActivityKit
import Foundation

/// Shared between the app and the VoidWidgets extension.
struct MeditationActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    /// When running, the adjusted start date such that `now - startDate == elapsed`.
    var startDate: Date
    /// Non-nil when paused: the total elapsed seconds, frozen at the pause.
    var pausedElapsedSeconds: Int?

    var isPaused: Bool {
      pausedElapsedSeconds != nil
    }
  }
}
