import SwiftUI
import ComposableArchitecture

struct SettingsControlBar: View {
  @Bindable var store: StoreOf<SettingsReducer>
  
  var body: some View {
    HStack {
      Spacer()
      
      actionButton
        .padding(.trailing, 12)
        .padding(.top, 8)
    }
  }
  
  @ViewBuilder
  private var actionButton: some View {
    HStack(alignment: .bottom, spacing: 24) {
      Button {
        Task {
          if store.isActive {
            store.send(.delegate(.stopMeditation), animation: .spring)
          } else {
            store.send(.delegate(.startMeditation), animation: .spring)
          }
        }
      } label: {
        HStack {
          Text(store.isActive ? "Finish" : "Begin")
            .contentTransition(.numericText(countsDown: false))
            .transition(.blurReplace.combined(with: .move(edge: .leading)))
        }
        .contentShape(.rect)
        .bold()
        .padding(12)
        .contentShape(.rect)
        .padding(.bottom, 4)
      }
      .padding(-12)
    }
    .buttonStyle(.plain)
    .sensoryFeedback(.impact(weight: .medium), trigger: store.isActive)
  }
}