import SwiftUI
import UIKit

struct DeviceSleepModifier: ViewModifier {
  var isPreventingSleep = false

  func body(content: Content) -> some View {
    content
      .onChange(of: isPreventingSleep, initial: true) {
        if isPreventingSleep {
          preventSleep()
        } else {
          allowSleep()
        }
      }
  }

  private func preventSleep() {
    UIApplication.shared.isIdleTimerDisabled = true
  }

  private func allowSleep() {
    UIApplication.shared.isIdleTimerDisabled = false
  }
}

extension View {
  func preventDeviceSleep(_ isPreventingSleep: Bool) -> some View {
    modifier(DeviceSleepModifier(isPreventingSleep: isPreventingSleep))
  }
}
