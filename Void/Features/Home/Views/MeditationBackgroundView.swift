import SwiftUI
import ComposableArchitecture

struct MeditationBackgroundView: View {
  let store: StoreOf<HomeReducer>
  
  var body: some View {
    ZStack {
      tapToDismissLayer
      meditationTimerLayer
    }
  }
  
  @ViewBuilder
  private var tapToDismissLayer: some View {
    Color.clear
      .contentShape(.rect)
      .onTapGesture {
        store.send(.settings(.select(nil)), animation: .settings)
      }
      .allowsHitTesting(store.settings.expandedSection != nil)
  }
  
  @ViewBuilder
  private var meditationTimerLayer: some View {
    if store.isActive,
       let meditationTimer = store.scope(state: \.meditationTimer, action: \.meditationTimer)
    {
      MeditationTimerView(store: meditationTimer)
        .allowsHitTesting(store.settings.expandedSection == nil)
        .transition(
          AnimationConstants.Transition.blurReplace.combined(
            with: .move(edge: .bottom)
          )
        )
    }
  }
}
