import ComposableArchitecture
import Inject
import SwiftUI

@Reducer
struct HomeReducer {
  @ObservableState
  struct State {
    @Shared(.meditationState) var meditationState
    var healthKitPermissionState: HealthKitPermissionState = .checking

    var settings: SettingsReducer.State = .init()
    var meditationTimer: MeditationTimerFeature.State?
    var stats: StatsFeature.State = .init()
    var onboarding: OnboardingFeature.State = .init()

    var isActive: Bool {
      meditationState != nil
    }

    enum HealthKitPermissionState {
      case checking
      case denied
      case granted
    }
  }

  enum Action: Equatable, Sendable {
    case meditationTimer(MeditationTimerFeature.Action)
    case settings(SettingsReducer.Action)
    case stats(StatsFeature.Action)
    case healthKitPermissions(enabled: Bool)
    case onboarding(OnboardingFeature.Action)
    case onAppear
  }

  @Dependency(\.date) var date
  @Dependency(\.healthKitClient) var healthKitClient
  @Dependency(\.liveActivityClient) var liveActivityClient
  @Dependency(\.soundManager) var audioManager

  var body: some ReducerOf<Self> {
    Scope(state: \.settings, action: \.settings) {
      SettingsReducer()
    }

    Scope(state: \.stats, action: \.stats) {
      StatsFeature()
    }

    Scope(state: \.onboarding, action: \.onboarding) {
      OnboardingFeature()
    }

    Reduce { state, action in
      switch action {
      case .onboarding(.delegate(.onboardingComplete)):
        withAnimation(.spring) {
          state.healthKitPermissionState = .granted
        }
        return .none

      case .settings(.delegate(.startMeditation)):
        return startMeditationFlow(&state)

      case .settings(.delegate(.stopMeditation)), .meditationTimer(.delegate(.timerCompleted)):
        return stopMeditationFlow(&state)

      case let .healthKitPermissions(enabled):
        state.healthKitPermissionState = enabled ? .granted : .denied
        return .none

      case .onAppear:
        return onAppearFlow(&state)

      case .settings:
        state.stats.isTodayExpanded = false
        state.stats.pendingDeletionID = nil
        return .none

      case .meditationTimer, .stats, .onboarding:
        return .none
      }
    }
    .ifLet(\.meditationTimer, action: \.meditationTimer) {
      MeditationTimerFeature()
    }
    .onChange(of: \.meditationState) { _, newValue in
      Reduce { state, _ in
        handleMeditationStateChange(state: &state)
        return .run { _ in
          await liveActivityClient.sync(newValue?.elapsedTime)
        }
      }
    }
  }
}

struct HomeView: View {
  @ObserveInjection var inject
  let store: StoreOf<HomeReducer>
  
  @Environment(\.scenePhase) private var scenePhase
  @Namespace private var namespace
  @State private var pulseTrigger = 0
  @State private var downPulseTrigger = 0

  var body: some View {
    contentView
      .keyboardAdaptive()
      .onChange(of: store.stats.editingSessionID) {
        let keyboard = KeyboardManager.shared
        if store.stats.editingSessionID != nil {
          keyboard.numberBinding = Binding(
            get: { store.stats.editedMinutes },
            set: { store.send(.stats(.binding(.set(\.editedMinutes, $0)))) }
          )
          keyboard.handleDismiss = { store.send(.stats(.commitEdit), animation: .nice) }
        }
        withAnimation(.nice) {
          keyboard.isVisible = store.stats.editingSessionID != nil
        }
      }
      .onDisappear {
        let keyboard = KeyboardManager.shared
        keyboard.isVisible = false
        keyboard.numberBinding = nil
        keyboard.handleDismiss = nil
      }
      .onChange(of: scenePhase) {
        if scenePhase == .active {
          store.send(.onAppear)
        }
      }
      .onAppear {
        store.send(.onAppear)
      }
      .preventDeviceSleep(store.isActive)
      .enableInjection()
  }
  
  @ViewBuilder
  private var contentView: some View {
    switch store.healthKitPermissionState {
    case .checking:
      Color.clear
    case .denied:
      NewOnboardingView(store: store.scope(state: \.onboarding, action: \.onboarding))
    case .granted:
      HomeContentView(
        store: store,
        namespace: namespace,
        pulseTrigger: $pulseTrigger,
        downPulseTrigger: $downPulseTrigger
      )
      .transition(.blurReplace)
    }
  }
}

#Preview("HomeView") {
  let store = Store(initialState: HomeReducer.State()) {
    HomeReducer()
  }
  return HomeView(store: store)
}
