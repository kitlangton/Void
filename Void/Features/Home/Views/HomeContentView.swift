import ComposableArchitecture
import SwiftUI

struct HomeContentView: View {
  let store: StoreOf<HomeReducer>
  let namespace: Namespace.ID
  @Binding var pulseTrigger: Int
  @Binding var downPulseTrigger: Int

  @Environment(\.colorScheme) private var colorScheme
  @State private var selectedPage = AppLaunchMode.screenshotPage == .streak ? 1 : 0

  private var backgroundColor: Color {
    colorScheme == .dark ? .black : .white
  }

  var body: some View {
    currentPageContent
      .onChange(of: store.isActive) {
        if store.isActive {
          selectedPage = 0
          pulseTrigger += 1
        } else {
          downPulseTrigger += 1
        }
      }
      .pulsing(pulseTrigger)
      .pulsing(downPulseTrigger, direction: .down)
  }

  /// The main page always lives inside the same `TabView` so its structural
  /// identity never changes when a session starts or ends. Only the streak
  /// page is added or removed, which keeps begin/finish transitions from
  /// rendering two crossfading copies of the main page.
  @ViewBuilder
  private var currentPageContent: some View {
    TabView(selection: $selectedPage) {
      HomeMainPageView(store: store, namespace: namespace)
        .tag(0)

      if !store.isActive {
        HomeStreakPageView(store: store)
          .tag(1)
      }
    }
    .tabViewStyle(.page(indexDisplayMode: .never))
    .indexViewStyle(.page(backgroundDisplayMode: .never))
    .background(backgroundColor)
  }
}

struct HomeMainPageView: View {
  let store: StoreOf<HomeReducer>
  let namespace: Namespace.ID

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
