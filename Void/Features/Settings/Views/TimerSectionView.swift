import SwiftUI
import ComposableArchitecture

struct TimerSectionView: View {
  @Bindable var store: StoreOf<SettingsReducer>
  let durations: [Int]
  let miniMode: Bool
  let isExpanded: Bool
  let otherSectionIsActive: Bool
  
  @State private var showingCustomDurationSheet = false
  
  var body: some View {
    ControlSection(
      title: "Timer",
      systemImage: "hourglass.tophalf.filled",
      selectedValue: store.settings.durationMinutes.map { "\($0)m" },
      isExpanded: isExpanded,
      onExpandedChange: { expanded in
        store.send(.select(expanded ? .timer : nil), animation: .nice)
      },
      otherSectionIsActive: otherSectionIsActive,
      miniMode: miniMode
    ) {
      if showingCustomDurationSheet {
        customDurationInput
      } else {
        durationGrid
      }
    }
    .accessibilityIdentifier("timer-section")
    .onChange(of: showingCustomDurationSheet) {
      withAnimation(.nice) {
        KeyboardManager.shared.isVisible = showingCustomDurationSheet
      }
    }
  }
  
  @ViewBuilder
  private var customDurationInput: some View {
    NumberInputView(
      binding: $store.settings.durationMinutes.animation(.spring),
      unit: "minute",
      handleDismiss: {
        showingCustomDurationSheet = false
        store.send(.select(nil), animation: .nice)
      }
    )
    .padding(.leading, 20)
    .padding(.bottom, 8)
    .transition(.blurReplace)
  }
  
  @ViewBuilder
  private var durationGrid: some View {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 8) {
      offButton
      durationButtons
      customInputButton
    }
    .transition(.blurReplace)
  }
  
  @ViewBuilder
  private var offButton: some View {
    SelectableButton(
      title: "Off",
      isSelected: store.settings.durationMinutes == nil
    ) {
      store.send(.setDurationMinutes(nil), animation: .nice)
    }
  }
  
  @ViewBuilder
  private var durationButtons: some View {
    ForEach(durations, id: \.self) { duration in
      SelectableButton(
        title: "\(duration)m",
        isSelected: store.settings.durationMinutes == duration
      ) {
        store.send(.setDurationMinutes(duration), animation: .nice)
      }
      .accessibilityIdentifier("\(duration)m")
    }
  }
  
  @ViewBuilder
  private var customInputButton: some View {
    Button {
      withAnimation(.nice) {
        showingCustomDurationSheet = true
      }
    } label: {
      Image(systemName: "keyboard.fill")
        .font(.title3)
        .frame(width: 44, height: 44)
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .foregroundStyle(.secondary)
  }
}