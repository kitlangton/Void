import ComposableArchitecture
import SwiftUI

struct HomeContentView: View {
  let store: StoreOf<HomeReducer>
  let namespace: Namespace.ID

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
        }
      }
      .onChange(of: selectedPage) {
        if selectedPage != 0, store.stats.isTodayExpanded {
          store.send(.stats(.dismissTodayExpansion), animation: .nice)
        }
      }
  }

  /// Keep both pages alive so the page container never snapshots and rebuilds
  /// the visible page during Begin/Finish.
  @ViewBuilder
  private var currentPageContent: some View {
    TabView(selection: $selectedPage) {
      HomeMainPageView(store: store, namespace: namespace)
        .tag(0)

      HomeStreakPageView(store: store)
        .tag(1)
    }
    .tabViewStyle(.page(indexDisplayMode: .never))
    .indexViewStyle(.page(backgroundDisplayMode: .never))
    .scrollDisabled(store.isActive)
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
        .contentShape(.rect)
        .onTapGesture {
          if store.stats.isTodayExpanded {
            store.send(.stats(.dismissTodayExpansion), animation: .nice)
          }
        }
    }
  }

  @ViewBuilder
  private var dimOverlay: some View {
    backgroundColor
      .opacity(store.settings.expandedSection != nil ? AnimationConstants.Opacity.dimOverlay : AnimationConstants.Opacity.hidden)
      .contentShape(.rect)
      .onTapGesture {
        store.send(.settings(.select(nil)), animation: .settings)
      }
      .allowsHitTesting(store.settings.expandedSection != nil)
  }
}
