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

      case .meditationTimer, .stats, .settings, .onboarding:
        return .none
      }
    }
    .ifLet(\.meditationTimer, action: \.meditationTimer) {
      MeditationTimerFeature()
    }
  }
}

// MARK: - Private Helper Methods

private extension HomeReducer {
  func handleMeditationStateChange(state: inout State) {
    if state.meditationState == nil {
      // If meditation ended, clear the timer
      state.meditationTimer = nil
    } else if let meditationState = Shared(state.$meditationState),
              state.meditationTimer == nil
    {
      // If meditation started, initialize the timer
      state.meditationTimer = MeditationTimerFeature.State(
        meditationState: meditationState,
        now: date.now
      )
    }
  }

  func startMeditationFlow(_ state: inout State) -> Effect<Action> {
    state.$meditationState.withLock { $0 = MeditationState(now: date.now) }
    handleMeditationStateChange(state: &state)

    return .run { send in
      await audioManager.play(sound: .startBell)
      await send(.meditationTimer(.start))
    }
  }

  func stopMeditationFlow(_ state: inout State) -> Effect<Action> {
    guard let meditationState = state.meditationState else {
      return .none
    }

    let now = date.now
    let secondsElapsed = meditationState.elapsedTime.secondsElapsed(now: now)
    let startDate = now.addingTimeInterval(-Double(secondsElapsed))

    // Save mindfulness session if duration is significant
    if secondsElapsed > 10 {
      Task {
        try await healthKitClient.saveMindfulnessSession(.init(startDate: startDate, endDate: now))
      }
    }

    withAnimation(.spring) {
      state.$meditationState.withLock { $0 = nil }
      handleMeditationStateChange(state: &state)
    }

    return .run { _ in
      await audioManager.play(sound: .completionBell)
      await AmbientManager.shared.stop()
    }
  }

  func onAppearFlow(_ state: inout State) -> Effect<Action> {
    handleMeditationStateChange(state: &state)
    state.healthKitPermissionState = healthKitClient.isAuthorized() ? .granted : .denied

    // Play ambient sound if currently active
    return .run { [state] _ in
      await audioManager.preloadSounds()
      if let ambientSound = state.settings.settings.ambience, state.isActive {
        await AmbientManager.shared.play(ambientSound)
      }
    }
  }
}

struct HomeView: View {
  @ObserveInjection var inject

  var store: StoreOf<HomeReducer>
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.scenePhase) private var scenePhase
  @Namespace var namespace
  @State private var pulseTrigger = 0
  @State private var downPulseTrigger = 0

  private var backgroundColor: Color { colorScheme == .dark ? .black : .white }

  @ViewBuilder
  var mainView: some View {
    switch store.healthKitPermissionState {
    case .checking:
      Color.clear
    case .denied:
      NewOnboardingView(store: store.scope(state: \.onboarding, action: \.onboarding))
    case .granted:
      mainContent
        .transition(.blurReplace)
    }
  }

  var body: some View {
    mainView
      .keyboardAdaptive()
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

  private var mainContent: some View {
    VStack(spacing: 0) {
      topContent
      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .overlay {
      backgroundColor.opacity(store.settings.expandedSection != nil ? 0.3 : 0).contentShape(.rect)
        .onTapGesture {
          store.send(.settings(.select(nil)), animation: .nice)
        }
        .allowsHitTesting(store.settings.expandedSection != nil)
    }
    .overlay(alignment: .bottom) {
      settingsOverlay
    }
    .background {
      backgroundLayers
    }
    .onChange(of: store.isActive) {
      if store.isActive {
        pulseTrigger += 1
      } else {
        downPulseTrigger += 1
      }
    }
    .pulsing(pulseTrigger)
    .pulsing(downPulseTrigger, direction: .down)
  }

  private var topContent: some View {
    VStack(spacing: 0) {
      if !store.isActive {
        logoAndStats
        QuotesView()
          .transition(.blurReplace.combined(with: .offset(y: -120)))
      }
    }
  }

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
    .transition(.blurReplace.combined(with: .offset(y: -80)))
  }

  private var settingsOverlay: some View {
    SettingsView(store: store.scope(state: \.settings, action: \.settings))
      .padding()
      .padding(.top)
      .background {
        LinearGradient(
          stops: [
            .init(color: .clear, location: 0),
            .init(color: backgroundColor, location: 0.1),
            .init(color: backgroundColor, location: 1),
          ],
          startPoint: .top,
          endPoint: .bottom
        )
      }
  }

  private var backgroundLayers: some View {
    ZStack {
      Color.clear.contentShape(.rect)
        .onTapGesture {
          store.send(.settings(.select(nil)), animation: .nice)
        }
        .allowsHitTesting(store.settings.expandedSection != nil)

      if let meditationTimer = store.scope(state: \.meditationTimer, action: \.meditationTimer) {
        MeditationTimerView(store: meditationTimer)
          .transition(.blurReplace.combined(with: .offset(y: 200)))
      }
    }
  }
}

#Preview("HomeView") {
  let store = Store(initialState: HomeReducer.State()) {
    HomeReducer()
  }
  return HomeView(store: store)
}
