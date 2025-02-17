import ComposableArchitecture
import Pow
import SwiftUI

@Reducer
struct OnboardingFeature {
  @ObservableState
  struct State: Equatable {
    var currentStep = Step.welcome
    var logoIsAnimating = false
    var isRequestingPermissions = false
    var appeared = false
    var userDeniedPermissions = false
    var healthKitPermission: HealthKitPermission = .notDetermined

    enum Step: Equatable {
      case welcome
      case healthKit

      var content: StepContent {
        switch self {
        case .welcome:
          StepContent(
            id: "welcome",
            title: Text("Welcome to ").foregroundStyle(.primary)
              + Text("VOID").fontWeight(.heavy).fontWidth(.expanded).foregroundStyle(.pink),
            description: Text("A simple meditation timer.")
          )
        case .healthKit:
          StepContent(
            id: "healthKit",
            title: Text("Track Your Progress"),
            description: Text(
              "Void uses HealthKit to save and track your meditation sessions."
            )
          )
        }
      }

      var next: Step? {
        switch self {
        case .welcome: .healthKit
        case .healthKit: nil
        }
      }
    }

    struct StepContent: Equatable {
      let id: String
      let title: Text
      let description: Text
    }
  }

  enum Action: Equatable {
    case onAppear
    case setAppeared
    case continueButtonTapped
    case requestHealthKitPermissions
    case healthKitPermissionsResponse(HealthKitPermission)
    case delegate(Delegate)

    enum Delegate: Equatable {
      case onboardingComplete
    }
  }

  @Dependency(\.healthKitClient) var healthKitClient

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .onAppear:
        return .run { send in
          try await Task.sleep(for: .seconds(0.2))
          await send(.setAppeared, animation: .spring(duration: 1))
        }

      case .setAppeared:
        state.appeared = true
        return .none

      case .continueButtonTapped:
        switch state.currentStep {
        case .welcome:
          state.currentStep = .healthKit
          return .none

        case .healthKit:
          if state.userDeniedPermissions {
            if let url = URL(string: "x-apple-health://") {
              UIApplication.shared.open(url)
            }
            return .none
          } else {
            return .send(.requestHealthKitPermissions)
          }
        }

      case .requestHealthKitPermissions:
        withAnimation(.nice) {
          state.isRequestingPermissions = true
        }
        return .run { send in
          let permission = try await healthKitClient.requestAuthorization()
          await send(.healthKitPermissionsResponse(permission))
        }

      case let .healthKitPermissionsResponse(permission):
        withAnimation(.nice) {
          state.isRequestingPermissions = false
          state.healthKitPermission = permission
        }

        switch permission {
        case .authorized:
          return .send(.delegate(.onboardingComplete), animation: .spring)
        default:
          withAnimation(.spring) {
            state.userDeniedPermissions = true
          }
          return .none
        }

      case .delegate:
        return .none
      }
    }
  }
}

struct NewOnboardingView: View {
  var store: StoreOf<OnboardingFeature>

  var phase: MovingLogoView.Phase {
    if store.appeared {
      switch store.currentStep {
      case .welcome: return .burst
      case .healthKit: return .spinning(speed: 4)
      }
    } else {
      return .closed
    }
  }

  var body: some View {
    VStack(spacing: 16) {
      Spacer()

      // Logo section
      MovingLogoView(phase: phase)
        .changeEffect(.glow(color: .pink, radius: 10), value: phase)
        .frame(width: 40, height: 40)
        .padding(.horizontal, 32)
        .offset(y: store.appeared ? 0 : -150)
        .opacity(store.appeared ? 1 : 0)
        .blur(radius: store.appeared ? 0 : 5)

      // Content section
      VStack(alignment: .center, spacing: 12) {
        if store.appeared {
          store.currentStep.content.title
            .font(.title3)
            .fontWeight(.bold)
            .contentTransition(.numericText())
            .id(store.currentStep.content.id)
            .transition(.blurReplace.combined(with: .offset(y: 20)))
        }

        if store.appeared {
          store.currentStep.content.description
            .font(.body.weight(.medium))
            .foregroundStyle(.secondary)
            .id(store.currentStep.content.id)
            .frame(maxWidth: .infinity, alignment: .center)
            .transition(.blurReplace.combined(with: .offset(y: 30)))
        }
      }
      .padding(.horizontal, 32)

      Spacer()

      // Bottom controls
      VStack(alignment: .center, spacing: 16) {
        if case .healthKit = store.currentStep {
          if store.userDeniedPermissions {
            VStack(alignment: .center, spacing: 16) {
              Text(
                "You'll need to manually enable permissions in the Sharing tab of the Health app."
              )
              .font(.body.weight(.medium))
              .foregroundStyle(.secondary)

              HStack(spacing: 4) {
                Text("Sharing")
                Image(systemName: "chevron.right")
                  .font(.caption.bold())
                Text("Apps")
                Image(systemName: "chevron.right")
                  .font(.caption.bold())
                Text("Void")
              }
              .font(.body.weight(.bold))
              .foregroundStyle(.secondary)

              Text("Make sure to enable both Read & Write access.")
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)
            }
            .transition(.blurReplace)
            .padding(.bottom, 24)
          }
        }

        HStack(spacing: 24) {
          if store.appeared {
            Button {
              store.send(.continueButtonTapped, animation: .spring)
            } label: {
              HStack {
                if store.currentStep == .healthKit {
                  Image(systemName: "heart.fill")
                    .foregroundStyle(.pink)
                    .transition(.blurReplace)
                }

                Text(buttonLabel)
                  .contentTransition(.numericText())
                  .fontWeight(.bold)
                  .opacity(store.isRequestingPermissions ? 0.6 : 1)
              }
              .padding(24)
              .frame(maxWidth: .infinity)
              .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .padding(-24)
            .disabled(store.isRequestingPermissions && !store.userDeniedPermissions)
            .transition(.blurReplace)
          }
        }
      }
      .padding(.bottom, 32)
      .padding(.horizontal, 32)
    }
    .pulsing(store.currentStep)
    .multilineTextAlignment(.center)
    .task { await store.send(.onAppear).finish() }
  }

  private var buttonLabel: String {
    switch store.currentStep {
    case .welcome:
      return "Continue"
    case .healthKit:
      return store.userDeniedPermissions ? "Open Health" : "Connect Apple Health"
    }
  }
}

#Preview {
  NewOnboardingView(
    store: Store(initialState: OnboardingFeature.State()) {
      OnboardingFeature()
    }
  )
  .preferredColorScheme(.dark)
}
