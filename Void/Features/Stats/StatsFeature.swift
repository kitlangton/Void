import ComposableArchitecture
import Inject
import SwiftUI

@Reducer
struct StatsFeature {
  @ObservableState
  struct State: Equatable {
    var dailyStats: DailyStats?
  }

  enum Action: Equatable {
    case task
    case updateStats(DailyStats)
    case scheduleMidnightRefresh
  }

  @Dependency(\.statsClient) var statsClient
  @Dependency(\.continuousClock) var clock
  @Dependency(\.date) var date

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .updateStats(stats):
        state.dailyStats = stats
        return .none

      case .scheduleMidnightRefresh:
        return .run { send in
          // Calculate time until next midnight
          let calendar = Calendar.current
          let now = date.now

          guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
                let nextMidnight = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: tomorrow)
          else { return }

          let timeUntilMidnight = nextMidnight.timeIntervalSince(now)

          try await clock.sleep(for: .seconds(timeUntilMidnight))

          // Refresh stats and schedule next refresh
          let stats = try await statsClient.getDailyStats()
          await send(.updateStats(stats), animation: .nice)
          await send(.scheduleMidnightRefresh)
        }

      case .task:
        return .merge(
          .run { send in
            let stats = try await statsClient.getDailyStats()
            await send(.updateStats(stats), animation: .nice)
          },
          .send(.scheduleMidnightRefresh)
        )
      }
    }
  }
}

struct NewStatsView: View {
  @ObserveInjection var inject
  var store: StoreOf<StatsFeature>

  @Environment(\.scenePhase) private var scenePhase

  var welcomeText: Text {
    let hour = Calendar.current.component(.hour, from: Date())
    if hour < 3 {
      return Text("Good very late night")
    } else if hour < 7 {
      return Text("Good early morning")
    } else if hour < 12 {
      return Text("Good morning")
    } else if hour < 18 {
      return Text("Good afternoon")
    } else {
      return Text("Good evening")
    }
  }

  var body: some View {
    HStack(spacing: 24) {
      VStack(alignment: .leading, spacing: 16) {
        if let streak = store.dailyStats?.streak, streak > 0 {
          (Text(String(streak))
            + Text(" day streak").foregroundStyle(.secondary)
          )
          .contentTransition(.numericText(value: Double(streak)))
          .transition(.blurReplace)
        }

        if let stats = store.dailyStats {
          if stats.totalMinutesToday > 0 {
            (Text("You practiced for ")
              .foregroundStyle(.secondary) + formatTime(stats.totalMinutesToday)
              + Text(" today")
              .foregroundStyle(.secondary))
              .contentTransition(.numericText(value: Double(stats.totalMinutesToday)))
              .transition(.blurReplace)
          } else if stats.streak > 0 {
            Text("Meditate to keep your streak going")
              .transition(.blurReplace)
          } else {
            welcomeText
              .transition(.blurReplace)
          }
        }
      }
      .fontWeight(.medium)
      .frame(maxWidth: .infinity, alignment: .leading)
      .transition(.blurReplace)
    }
    .task {
      await store.send(.task).finish()
    }
    .onChange(of: scenePhase) { _, newPhase in
      if newPhase == .active {
        Task {
          await store.send(.task).finish()
        }
      }
    }
    .font(.system(.headline))
    .enableInjection()
  }

  private func formatTime(_ minutes: Double) -> Text {
    let totalSeconds = Int(minutes * 60)
    let hours = totalSeconds / 3600
    let remainingMinutes = (totalSeconds % 3600) / 60
    let seconds = totalSeconds % 60

    if minutes < 1 {
      return Text("\(seconds) \(seconds == 1 ? "second" : "seconds")")
    }

    if hours == 0 {
      return Text("\(remainingMinutes) \(remainingMinutes == 1 ? "minute" : "minutes")")
    } else {
      let hourText = Text("\(hours) \(hours == 1 ? "hour" : "hours")")
      let minuteText =
        remainingMinutes > 0
          ? Text(" and ").foregroundStyle(.secondary)
          + Text("\(remainingMinutes) \(remainingMinutes == 1 ? "minute" : "minutes")")
          : Text("")
      return hourText + minuteText
    }
  }
}

#Preview("StatsView") {
  let store = Store(initialState: StatsFeature.State()) {
    StatsFeature()
  } withDependencies: {
    $0.statsClient.getDailyStats = {
      DailyStats(streak: 8, totalMinutesToday: 0)
    }
  }
  NewStatsView(store: store)
}
