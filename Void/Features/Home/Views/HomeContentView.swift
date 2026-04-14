import SwiftUI
import ComposableArchitecture

struct HomeContentView: View {
  let store: StoreOf<HomeReducer>
  let namespace: Namespace.ID
  @Binding var pulseTrigger: Int
  @Binding var downPulseTrigger: Int
  
  @Environment(\.colorScheme) private var colorScheme
  private var backgroundColor: Color { 
    colorScheme == .dark ? .black : .white 
  }
  
  var body: some View {
    VStack(spacing: 0) {
      HomeHeaderView(store: store, namespace: namespace)
      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .overlay {
      dimOverlay
    }
    .overlay(alignment: .bottom) {
      HomeSettingsOverlay(store: store)
    }
    .background {
      MeditationBackgroundView(store: store)
    }
    .onChange(of: store.isActive) {
      if store.isActive {
        pulseTrigger += 1
      } else {
        downPulseTrigger += 1
      }
    }
    .pulsing(pulseTrigger)
    .pulsing(downPulseTrigger, direction: .down)
  }
  
  @ViewBuilder
  private var dimOverlay: some View {
    backgroundColor
      .opacity(store.settings.expandedSection != nil ? AnimationConstants.Opacity.dimOverlay : AnimationConstants.Opacity.hidden)
      .contentShape(.rect)
      .onTapGesture {
        store.send(.settings(.select(nil)), animation: .nice)
      }
      .allowsHitTesting(store.settings.expandedSection != nil)
  }
}
