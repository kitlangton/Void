import SwiftUI
import ComposableArchitecture

struct HomeHeaderView: View {
  let store: StoreOf<HomeReducer>
  let namespace: Namespace.ID
  
  var body: some View {
    VStack(spacing: 0) {
      if !store.isActive {
        logoAndStats
        QuotesView()
          .transition(AnimationConstants.Transition.blurReplace.combined(with: .offset(y: AnimationConstants.Transition.quoteOffset)))
      }
    }
  }
  
  @ViewBuilder
  private var logoAndStats: some View {
    HStack(alignment: .top) {
      VStack(alignment: .leading, spacing: 16) {
        RotatingLogoView()
          .frame(width: 24, height: 24)
          .matchedGeometryEffect(id: "logo", in: namespace)
        
        NewStatsView(store: store.scope(state: \.stats, action: \.stats))
      }
      .padding(.top, 14)
      .padding(.horizontal)
      .padding()
      
      Spacer()
    }
    .transition(AnimationConstants.Transition.blurReplace.combined(with: .offset(y: AnimationConstants.Transition.logoOffset)))
  }
}