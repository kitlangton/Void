import SwiftUI
import ComposableArchitecture

struct HomeSettingsOverlay: View {
  let store: StoreOf<HomeReducer>
  @Environment(\.colorScheme) private var colorScheme
  
  private var backgroundColor: Color { 
    colorScheme == .dark ? .black : .white 
  }

  /// While a sit's duration is being edited, the settings recede entirely so
  /// the digit keyboard clearly belongs to the row above.
  private var isEditingSit: Bool {
    store.stats.editingSessionID != nil
  }

  var body: some View {
    SettingsView(store: store.scope(state: \.settings, action: \.settings))
      .padding()
      .padding(.top)
      .background {
        backgroundGradient
      }
      .opacity(isEditingSit ? 0 : 1)
      .offset(y: isEditingSit ? 24 : 0)
      .allowsHitTesting(!isEditingSit)
      .animation(.nice, value: isEditingSit)
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
