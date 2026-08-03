import SwiftUI
import ComposableArchitecture

struct HomeHeaderView: View {
  let store: StoreOf<HomeReducer>
  let namespace: Namespace.ID
  @State private var boostsLogoOnAppear = false
  
  var body: some View {
    VStack(spacing: 0) {
      if !store.isActive {
        logoAndStats
        QuotesView()
          .opacity(store.stats.isTodayExpanded ? 0.25 : 1)
          .animation(.nice, value: store.stats.isTodayExpanded)
          .onTapGesture {
            if store.stats.isTodayExpanded {
              store.send(.stats(.dismissTodayExpansion), animation: .nice)
            }
          }
          .transition(
            AnimationConstants.Transition.blurReplace.combined(
              with: .move(edge: .top)
            )
          )
      }
    }
    .onChange(of: store.isActive) { _, isActive in
      if !isActive {
        boostsLogoOnAppear = true
      }
    }
  }
  
  @ViewBuilder
  private var logoAndStats: some View {
    HStack(alignment: .top) {
      VStack(alignment: .leading, spacing: 16) {
        RotatingLogoView(boostsOnAppear: boostsLogoOnAppear)
          .frame(width: 24, height: 24)
          .matchedGeometryEffect(id: "logo", in: namespace)
        
        NewStatsView(store: store.scope(state: \.stats, action: \.stats))
      }
      .padding(.top, 14)
      .padding(.horizontal)
      .padding()
      
      Spacer()
    }
    .transition(
      AnimationConstants.Transition.blurReplace.combined(
        with: .move(edge: .top)
      )
    )
  }
}
