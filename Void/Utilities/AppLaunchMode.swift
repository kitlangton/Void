import Foundation

enum AppLaunchMode {
  static let screenshotEnabled = ProcessInfo.processInfo.environment["VOID_SCREENSHOT_MODE"] == "1"

  enum Page: String {
    case home
    case streak
    case timer
    case intervals
  }

  static let screenshotPage: Page = {
    guard screenshotEnabled,
          let rawValue = ProcessInfo.processInfo.environment["VOID_SCREENSHOT_PAGE"],
          let page = Page(rawValue: rawValue)
    else {
      return .home
    }

    return page
  }()
}
