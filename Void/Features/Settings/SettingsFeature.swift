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
  @Dependency(\.soundManager) var audioManager

  enum CancelID: Hashable {
    case ambient
  }

  @ObservableState
  struct State {
    @Shared(.settings) var settings: VoidSettings
    @Shared(.expandedSection) var expandedSection: SettingSection?
    @Shared(.meditationState) var meditationState: MeditationState?

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
        return syncAmbientPlayback(for: state)

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
          state.$settings.ambience.withLock { $0 = ambience }
          return syncAmbientPlayback(for: state)
        }

      case .binding:
        return .none

      case .delegate:
        return .send(.select(nil))
      }
    }
  }

  private func syncAmbientPlayback(for state: State) -> Effect<Action> {
    let ambient = state.isActive || state.expandedSection == .ambient
      ? state.settings.ambience
      : nil

    return .run { _ in
      await audioManager.setAmbient(ambient)
    }
    .cancellable(id: CancelID.ambient, cancelInFlight: true)
  }
}

struct SettingsView: View {
  @ObserveInjection var inject
  @Bindable var store: StoreOf<SettingsReducer>
  @State private var keyboardManager = KeyboardManager.shared

  private var miniMode: Bool {
    store.isActive
  }
  
  private var isMiniActive: Bool {
    miniMode && store.expandedSection == nil
  }

  var body: some View {
    layout {
      VStack(alignment: .leading) {
        sections
      }

      if !keyboardManager.isVisible {
        SettingsControlBar(store: store)
          .transition(.blurReplace)
      }
    }
    .padding(.bottom, 12)
    .sensoryFeedback(.selection, trigger: store.expandedSection)
    .background(tapToDismissLayer)
    .enableInjection()
  }
  
  @ViewBuilder
  private var sections: some View {
    TimerSectionView(
      store: store,
      durations: SettingsConstants.Timer.availableDurations,
      miniMode: isMiniActive,
      isExpanded: store.expandedSection == .timer,
      otherSectionIsActive: otherSectionIsActive(section: .timer)
    )
    
    IntervalsSectionView(
      store: store,
      intervals: SettingsConstants.Intervals.availableIntervals,
      miniMode: isMiniActive,
      isExpanded: store.expandedSection == .intervals,
      otherSectionIsActive: otherSectionIsActive(section: .intervals)
    )
    
    AmbienceSectionView(
      store: store,
      ambientSounds: AmbientSound.allCases,
      upcomingAmbience: SettingsConstants.Ambience.upcomingSounds,
      miniMode: isMiniActive,
      isExpanded: store.expandedSection == .ambient,
      otherSectionIsActive: otherSectionIsActive(section: .ambient)
    )
  }
  
  @ViewBuilder
  private var tapToDismissLayer: some View {
    Color.clear
      .contentShape(.rect)
      .onTapGesture {
        store.send(.select(nil), animation: .settings)
      }
  }

  private var layout: some Layout {
    if isMiniActive {
      return AnyLayout(HStackLayout(alignment: .bottom, spacing: 6))
    } else {
      return AnyLayout(VStackLayout(spacing: 12))
    }
  }

  private func otherSectionIsActive(section: SettingSection) -> Bool {
    store.expandedSection != nil && store.expandedSection != section
  }
}

#Preview("SettingsView") {
  let state = SettingsReducer.State()
  let store = Store(initialState: state) {
    SettingsReducer()
  }
  return SettingsView(store: store)
}
