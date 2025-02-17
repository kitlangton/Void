import ComposableArchitecture
import Inject
import SwiftUI

enum SettingSection: Equatable {
  case timer
  case intervals
  case ambient
}

extension SharedKey where Self == InMemoryKey<SettingSection?>.Default {
  static var expandedSection: Self {
    Self[.inMemory("expanded-section"), default: nil]
  }
}

@Reducer
struct SettingsReducer {
  @ObservableState
  struct State {
    @Shared(.settings) var settings: VoidSettings
    @Shared(.expandedSection) var expandedSection: SettingSection?
    @Shared(.meditationState) var meditationState: MeditationState?
    var showingCustomDurationSheet = false
    var showingCustomIntervalSheet = false

    var isActive: Bool {
      meditationState != nil
    }
  }

  enum Action: Equatable, BindableAction {
    case binding(BindingAction<State>)
    case delegate(Delegate)
    case select(SettingSection?)

    case setIntervalMinutes(Int?)
    case setDurationMinutes(Int?)
    case setAmbience(AmbientSound?)

    enum Delegate: Equatable {
      case startMeditation
      case stopMeditation
    }
  }

  var body: some ReducerOf<Self> {
    BindingReducer()

    Reduce { state, action in
      switch action {
      case let .select(section):
        state.$expandedSection.withLock { $0 = section }

        state.showingCustomDurationSheet = false
        state.showingCustomIntervalSheet = false

        if section != .ambient && !state.isActive {
          Task { @MainActor in
            AmbientManager.shared.stop()
          }
        } else if let ambience = state.settings.ambience {
          Task { @MainActor in
            AmbientManager.shared.play(ambience)
          }
        }

        return .none

      case let .setIntervalMinutes(interval):
        if interval == state.settings.intervalMinutes {
          return .send(.select(nil))
        } else {
          state.$settings.intervalMinutes.withLock { $0 = interval }
          return .none
        }

      case let .setDurationMinutes(duration):
        if duration == state.settings.durationMinutes {
          return .send(.select(nil))
        } else {
          state.$settings.durationMinutes.withLock { $0 = duration }
        }
        return .none

      case let .setAmbience(ambience):
        if ambience == state.settings.ambience {
          return .send(.select(nil))
        } else {
          Task { @MainActor in
            if let ambience = ambience {
              AmbientManager.shared.play(ambience)
            } else {
              AmbientManager.shared.stop()
            }
          }
          state.$settings.ambience.withLock { $0 = ambience }
        }
        return .none

      case .binding:
        return .none

      case .delegate:
        return .send(.select(nil))
      }
    }
  }
}

struct SettingsView: View {
  @ObserveInjection var inject
  @Bindable var store: StoreOf<SettingsReducer>

  var miniMode: Bool {
    store.isActive
  }

  let durations = [5, 10, 15, 30, 45, 60, 90, 120]
  let intervals = [10, 15, 30]
  let ambientSounds = AmbientSound.allCases

  @State var keyboardManager = KeyboardManager.shared

  var body: some View {
    layout {
      VStack(alignment: .leading) {
        timerSection
        intervalSection
        ambienceSection
      }

      if !keyboardManager.isVisible {
        HStack {
          Spacer()

          startStopControls
            .padding(.trailing, 12)
            .padding(.top, 8)
        }
        .transition(.blurReplace)
      }
    }
    .padding(.bottom, 12)
    .sensoryFeedback(.selection, trigger: store.expandedSection)
    .sensoryFeedback(.selection, trigger: store.showingCustomDurationSheet)
    .sensoryFeedback(.selection, trigger: store.showingCustomIntervalSheet)
    .background {
      Color.clear.contentShape(.rect)
        .onTapGesture {
          store.send(.select(nil), animation: .nice)
        }
    }
    .onChange(of: store.showingCustomDurationSheet) {
      withAnimation(.nice) {
        KeyboardManager.shared.isVisible = store.showingCustomDurationSheet
      }
    }
    .onChange(of: store.showingCustomIntervalSheet) {
      withAnimation(.nice) {
        KeyboardManager.shared.isVisible = store.showingCustomIntervalSheet
      }
    }
    .enableInjection()
  }

  var layout: some Layout {
    if isMiniActive {
      return AnyLayout(HStackLayout(alignment: .bottom, spacing: 6))
    } else {
      return AnyLayout(VStackLayout(spacing: 12))
    }
  }

  var isMiniActive: Bool {
    miniMode && store.expandedSection == nil
  }

  func otherSectionIsActive(section: SettingSection) -> Bool {
    store.expandedSection != nil && store.expandedSection != section
  }

  var durationBinding: Binding<Int?> {
    $store.settings.durationMinutes
  }

  var intervalBinding: Binding<Int?> {
    $store.settings.intervalMinutes
  }

  @ViewBuilder
  var durationInputView: some View {
    NumberInputView(
      binding: durationBinding.animation(.spring),
      unit: "minute",
      handleDismiss: {
        store.send(.select(nil), animation: .nice)
      }
    )
  }

  @ViewBuilder
  var intervalInputView: some View {
    NumberInputView(
      binding: intervalBinding.animation(.spring),
      unit: "minute",
      handleDismiss: {
        store.send(.select(nil), animation: .nice)
      }
    )
  }

  var invalidInterval: Bool {
    guard let duration = store.settings.durationMinutes,
          let interval = store.settings.intervalMinutes
    else { return false }

    return duration <= interval
  }

  var startStopControls: some View {
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

  @ViewBuilder
  var timerSection: some View {
    ControlSection(
      title: "Timer",
      systemImage: "hourglass.tophalf.filled",
      selectedValue: store.settings.durationMinutes.map { "\($0)m" },
      isExpanded: store.expandedSection == .timer,
      onExpandedChange: { isExpanded in
        store.send(.select(isExpanded ? .timer : nil), animation: .nice)
      },
      otherSectionIsActive: otherSectionIsActive(section: .timer),
      miniMode: isMiniActive
    ) {
      if store.showingCustomDurationSheet {
        durationInputView
          .padding(.leading, 20)
          .padding(.bottom, 8)
          .transition(.blurReplace)
      } else {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 8) {
          SelectableButton(
            title: "Off",
            isSelected: store.settings.durationMinutes == nil
          ) {
            store.send(.setDurationMinutes(nil), animation: .nice)
          }

          ForEach(durations, id: \.self) { duration in
            SelectableButton(
              title: "\(duration)m",
              isSelected: store.settings.durationMinutes == duration
            ) {
              store.send(.setDurationMinutes(duration), animation: .nice)
            }
            .accessibilityIdentifier("\(duration)m")
          }

          Button {
            withAnimation(.nice) {
              store.showingCustomDurationSheet = true
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
        .transition(.blurReplace)
      }
    }
    .accessibilityIdentifier("timer-section")
  }

  @ViewBuilder
  var intervalSection: some View {
    ControlSection(
      title: "Intervals",
      systemImage: "bell",
      selectedValue: store.settings.intervalMinutes.map { "\($0)m" },
      isExpanded: store.expandedSection == .intervals,
      onExpandedChange: { isExpanded in
        store.send(.select(isExpanded ? .intervals : nil), animation: .nice)
      },
      otherSectionIsActive: otherSectionIsActive(section: .intervals),
      miniMode: isMiniActive
    ) {
      if let interval = store.settings.intervalMinutes,
         let duration = store.settings.durationMinutes,
         invalidInterval
      {
        HStack(spacing: 4) {
          Image(systemName: "exclamationmark.triangle.fill")
          Text(
            duration == interval
              ? "The interval is equal to the timer" : "The interval is longer than the timer")
        }
        .font(.system(.caption).weight(.medium))
        .foregroundStyle(.secondary)
        .transition(.blurReplace)
      }

      if store.showingCustomIntervalSheet {
        intervalInputView
          .padding(.leading, 20)
          .padding(.bottom, 8)
          .transition(.blurReplace)
      } else {
        HStack(spacing: 8) {
          SelectableButton(
            title: "Off",
            isSelected: store.settings.intervalMinutes == nil
          ) {
            store.send(.setIntervalMinutes(nil), animation: .nice)
          }

          ForEach(intervals, id: \.self) { interval in
            SelectableButton(
              title: "\(interval)m",
              isSelected: store.settings.intervalMinutes == interval
            ) {
              store.send(.setIntervalMinutes(interval), animation: .nice)
            }
            .accessibilityIdentifier("\(interval)m")
          }

          Button {
            withAnimation(.nice) {
              store.showingCustomIntervalSheet = true
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
        .transition(.blurReplace)
      }
    }
    .symbolVariant(invalidInterval ? .slash : .none)
    .accessibilityIdentifier("intervals-section")
  }

  @ViewBuilder
  var ambienceSection: some View {
    ControlSection(
      title: "Ambience",
      systemImage: "water.waves",
      selectedValue: store.settings.ambience?.title,
      isExpanded: store.expandedSection == .ambient,
      onExpandedChange: { isExpanded in
        store.send(.select(isExpanded ? .ambient : nil), animation: .nice)
      },
      otherSectionIsActive: otherSectionIsActive(section: .ambient),
      miniMode: isMiniActive
    ) {
      VStack(alignment: .center) {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
          SelectableButton(
            title: "Off",
            isSelected: store.settings.ambience == nil
          ) {
            store.send(.setAmbience(nil), animation: .nice)
          }

          ForEach(ambientSounds, id: \.self) { sound in
            SelectableButton(
              title: sound.title,
              isSelected: store.settings.ambience == sound
            ) {
              store.send(.setAmbience(sound), animation: .nice)
            }
          }

          ForEach(upcomingAmbience, id: \.self) { sound in
            SelectableButton(
              title: sound,
              isSelected: false
            ) {
              print("Previewing \(sound)")
            }.disabled(true)
          }
        }
      }
    }
    .accessibilityIdentifier("ambience-section")
  }

  let upcomingAmbience = ["Forest", "Cemetery", "Hell Realm"]
}

#Preview("SettingsView") {
  let state = SettingsReducer.State()
  let store = Store(initialState: state) {
    SettingsReducer()
  }
  return SettingsView(store: store)
}
