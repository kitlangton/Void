import Foundation

enum SettingsConstants {
  enum Timer {
    static let availableDurations = [5, 10, 15, 30, 45, 60, 90, 120]
    static let defaultDuration: Int? = nil
  }
  
  enum Intervals {
    static let availableIntervals = [10, 15, 30]
    static let defaultInterval: Int? = nil
  }
  
  enum Ambience {
    static let upcomingSounds = ["Forest", "Cemetery", "Hell Realm"]
  }
  
  enum Animation {
    static let standardDuration = 0.3
    static let springResponse = 0.5
    static let springDamping = 0.8
  }
}