import SwiftUI
import ComposableArchitecture

struct IntervalsSectionView: View {
  @Bindable var store: StoreOf<SettingsReducer>
  let intervals: [Int]
  let miniMode: Bool
  let isExpanded: Bool
  let otherSectionIsActive: Bool
  
  @State private var showingCustomIntervalSheet = false
  
  private var invalidInterval: Bool {
    guard let duration = store.settings.durationMinutes,
          let interval = store.settings.intervalMinutes
    else { return false }
    
    return duration <= interval
  }
  
  var body: some View {
    ControlSection(
      title: "Intervals",
      systemImage: "bell",
      selectedValue: store.settings.intervalMinutes.map { "\($0)m" },
      isExpanded: isExpanded,
      onExpandedChange: { expanded in
        store.send(.select(expanded ? .intervals : nil), animation: .nice)
      },
      otherSectionIsActive: otherSectionIsActive,
      miniMode: miniMode
    ) {
      VStack(alignment: .leading, spacing: 8) {
        if invalidInterval {
          warningMessage
        }
        
        if showingCustomIntervalSheet {
          customIntervalInput
        } else {
          intervalButtons
        }
      }
    }
    .symbolVariant(invalidInterval ? .slash : .none)
    .accessibilityIdentifier("intervals-section")
    .onChange(of: showingCustomIntervalSheet) {
      withAnimation(.nice) {
        KeyboardManager.shared.isVisible = showingCustomIntervalSheet
      }
    }
  }
  
  @ViewBuilder
  private var warningMessage: some View {
    HStack(spacing: 4) {
      Image(systemName: "exclamationmark.triangle.fill")
      Text(intervalWarningText)
    }
    .font(.system(.caption).weight(.medium))
    .foregroundStyle(.secondary)
    .transition(.blurReplace)
  }
  
  private var intervalWarningText: String {
    guard let duration = store.settings.durationMinutes,
          let interval = store.settings.intervalMinutes
    else { return "" }
    
    return duration == interval
      ? "The interval is equal to the timer"
      : "The interval is longer than the timer"
  }
  
  @ViewBuilder
  private var customIntervalInput: some View {
    NumberInputView(
      binding: Binding(
        get: { store.settings.intervalMinutes },
        set: { store.send(.setIntervalMinutes($0), animation: .spring) }
      ),
      unit: "minute",
      handleDismiss: {
        showingCustomIntervalSheet = false
        store.send(.select(nil), animation: .nice)
      }
    )
    .padding(.leading, 20)
    .padding(.bottom, 8)
    .transition(.blurReplace)
  }
  
  @ViewBuilder
  private var intervalButtons: some View {
    HStack(spacing: 8) {
      offButton
      intervalOptions
      customInputButton
    }
    .transition(.blurReplace)
  }
  
  @ViewBuilder
  private var offButton: some View {
    SelectableButton(
      title: "Off",
      isSelected: store.settings.intervalMinutes == nil
    ) {
      store.send(.setIntervalMinutes(nil), animation: .nice)
    }
  }
  
  @ViewBuilder
  private var intervalOptions: some View {
    ForEach(intervals, id: \.self) { interval in
      SelectableButton(
        title: "\(interval)m",
        isSelected: store.settings.intervalMinutes == interval
      ) {
        store.send(.setIntervalMinutes(interval), animation: .nice)
      }
      .accessibilityIdentifier("\(interval)m")
    }
  }
  
  @ViewBuilder
  private var customInputButton: some View {
    Button {
      withAnimation(.nice) {
        showingCustomIntervalSheet = true
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
