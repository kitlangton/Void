import SwiftUI

enum AnimationConstants {
  enum Transition {
    static let logoOffset: CGFloat = -80
    static let quoteOffset: CGFloat = -120
    static let timerOffset: CGFloat = 200
    
    static let blurReplace = AnyTransition.opacity
    static let fadeMove = AnyTransition.asymmetric(
      insertion: .opacity.combined(with: .move(edge: .bottom)),
      removal: .opacity.combined(with: .move(edge: .top))
    )
  }
  
  enum Gradient {
    static let fadeStartLocation: Double = 0
    static let fadeMiddleLocation: Double = 0.1
    static let fadeEndLocation: Double = 1
  }
  
  enum Opacity {
    static let dimOverlay: Double = 0.3
    static let hidden: Double = 0
    static let visible: Double = 1
  }
  
  enum Timing {
    static let standard = Animation.spring
    static let nice = Animation.nice
  }
}
