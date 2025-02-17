import Foundation

struct ElapsedTime: Equatable, Codable {
  var bankedTime: TimeInterval = 0
  var startedAt: Date = .init()
  var pausedAt: Date?

  init(startedAt: Date) {
    self.startedAt = startedAt
  }

  var isPaused: Bool {
    pausedAt != nil
  }

  mutating func pause(now: Date) {
    bankedTime += now.timeIntervalSince(startedAt)
    pausedAt = now
  }

  mutating func resume(now: Date) {
    startedAt = now
    pausedAt = nil
  }

  func secondsElapsed(now: Date) -> Int {
    Int(elapsed(now: now))
  }

  func elapsed(now: Date) -> TimeInterval {
    if isPaused {
      return bankedTime
    } else {
      return bankedTime + now.timeIntervalSince(startedAt)
    }
  }
}
