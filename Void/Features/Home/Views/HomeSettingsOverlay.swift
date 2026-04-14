import SwiftUI
import ComposableArchitecture

struct HomeSettingsOverlay: View {
  let store: StoreOf<HomeReducer>
  @Environment(\.colorScheme) private var colorScheme
  
  private var backgroundColor: Color { 
    colorScheme == .dark ? .black : .white 
  }
  
  var body: some View {
    SettingsView(store: store.scope(state: \.settings, action: \.settings))
      .padding()
      .padding(.top)
      .background {
        backgroundGradient
      }
  }
  
  @ViewBuilder
  private var backgroundGradient: some View {
    LinearGradient(
      stops: [
        .init(color: .clear, location: AnimationConstants.Gradient.fadeStartLocation),
        .init(color: backgroundColor, location: AnimationConstants.Gradient.fadeMiddleLocation),
        .init(color: backgroundColor, location: AnimationConstants.Gradient.fadeEndLocation),
      ],
      startPoint: .top,
      endPoint: .bottom
    )
  }
}
