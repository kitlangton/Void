import ComposableArchitecture
import Inject
import SwiftUI

@Reducer
struct StatsFeature {
  @ObservableState
  struct State: Equatable {
    var dailyStats: DailyStats?
    var todaysSessions: [MindfulSessionSample] = []
    var isTodayExpanded = false
    var selectedDay: Date?
    var selectedDaySessions: [MindfulSessionSample] = []
    var editingSessionID: UUID?
    var editedMinutes: Int?
    var pendingDeletionID: UUID?

    func session(id: UUID) -> MindfulSessionSample? {
      todaysSessions.first(where: { $0.id == id })
        ?? selectedDaySessions.first(where: { $0.id == id })
    }
  }

  enum Action: Equatable, BindableAction {
    case binding(BindingAction<State>)
    case task
    case updateStats(DailyStats)
    case updateTodaysSessions([MindfulSessionSample])
    case updateSelectedDaySessions(Date, [MindfulSessionSample])
    case toggleTodayExpanded
    case dismissTodayExpansion
    case selectDay(Date?)
    case deleteSession(UUID)
    case beginEditingSession(UUID)
    case commitEdit
  }

  private enum CancelID {
    case midnightRefresh
    case selectedDayRefresh
  }

  @Dependency(\.statsClient) var statsClient
  @Dependency(\.healthKitClient) var healthKitClient
  @Dependency(\.continuousClock) var clock
  @Dependency(\.date) var date

  var body: some ReducerOf<Self> {
    BindingReducer()

    Reduce { state, action in
      switch action {
      case .binding:
        return .none

      case let .updateStats(stats):
        state.dailyStats = stats
        return .none

      case let .updateTodaysSessions(sessions):
        state.todaysSessions = sessions
        if sessions.isEmpty {
          state.isTodayExpanded = false
        }
        return .none

      case let .updateSelectedDaySessions(day, sessions):
        guard state.selectedDay.map({ Calendar.current.isDate($0, inSameDayAs: day) }) == true else {
          return .none
        }
        state.selectedDaySessions = sessions
        return .none

      case .toggleTodayExpanded:
        state.isTodayExpanded.toggle()
        state.editingSessionID = nil
        state.editedMinutes = nil
        state.pendingDeletionID = nil
        guard state.isTodayExpanded else { return .none }
        return refreshTodayEffect()

      case .dismissTodayExpansion:
        state.isTodayExpanded = false
        state.editingSessionID = nil
        state.editedMinutes = nil
        state.pendingDeletionID = nil
        return .none

      case let .selectDay(day):
        state.editingSessionID = nil
        state.editedMinutes = nil
        state.pendingDeletionID = nil

        if let day, state.selectedDay != day {
          state.selectedDay = day
          state.selectedDaySessions = []
          return refreshSelectedDayEffect(day)
        } else {
          state.selectedDay = nil
          state.selectedDaySessions = []
          return .cancel(id: CancelID.selectedDayRefresh)
        }

      case let .deleteSession(id):
        guard state.pendingDeletionID == id else {
          state.pendingDeletionID = id
          state.editingSessionID = nil
          state.editedMinutes = nil
          return .none
        }

        state.pendingDeletionID = nil
        state.todaysSessions.removeAll { $0.id == id }
        state.selectedDaySessions.removeAll { $0.id == id }
        return .run { [selectedDay = state.selectedDay] send in
          do {
            try await healthKitClient.deleteMindfulSession(id)
          } catch {
            print("Failed to delete mindful session: \(error)")
          }
          await refresh(send, selectedDay: selectedDay)
        }

      case let .beginEditingSession(id):
        /// Re-tapping the row being edited must not reset the typed value.
        guard state.editingSessionID != id,
              let session = state.session(id: id)
        else { return .none }
        state.editingSessionID = id
        state.editedMinutes = max(1, session.minutes)
        state.pendingDeletionID = nil
        return .none

      case .commitEdit:
        guard let id = state.editingSessionID,
              let session = state.session(id: id)
        else {
          state.editingSessionID = nil
          state.editedMinutes = nil
          return .none
        }

        let minutes = max(1, state.editedMinutes ?? session.minutes)
        state.editingSessionID = nil
        state.editedMinutes = nil

        guard minutes != session.minutes else { return .none }

        let updated = MindfulSession(
          startDate: session.startDate,
          endDate: session.startDate.addingTimeInterval(Double(minutes) * 60)
        )

        return .run { [selectedDay = state.selectedDay] send in
          do {
            try await healthKitClient.updateMindfulSession(id, updated)
          } catch {
            print("Failed to update mindful session: \(error)")
          }
          await refresh(send, selectedDay: selectedDay)
        }

      case .task:
        return .merge(
          refreshEffect(selectedDay: state.selectedDay),
          .run { send in
            while !Task.isCancelled {
              let calendar = Calendar.current
              let now = date.now
              guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
                    let nextMidnight = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: tomorrow)
              else { return }

              try await clock.sleep(for: .seconds(nextMidnight.timeIntervalSince(now)))
              await refresh(send, selectedDay: nil)
            }
          }
          .cancellable(id: CancelID.midnightRefresh, cancelInFlight: true)
        )
      }
    }
  }

  private func refreshEffect(selectedDay: Date?) -> Effect<Action> {
    .run { send in
      await refresh(send, selectedDay: selectedDay)
    }
  }

  private func refreshTodayEffect() -> Effect<Action> {
    .run { send in
      guard let sessions = try? await healthKitClient.getSessions(date.now) else { return }
      await send(.updateTodaysSessions(sessions), animation: .nice)
    }
  }

  private func refreshSelectedDayEffect(_ day: Date) -> Effect<Action> {
    .run { send in
      guard let sessions = try? await healthKitClient.getSessions(day) else { return }
      await send(.updateSelectedDaySessions(day, sessions), animation: .nice)
    }
    .cancellable(id: CancelID.selectedDayRefresh, cancelInFlight: true)
  }

  private func refresh(_ send: Send<Action>, selectedDay: Date?) async {
    let now = date.now
    async let statsResult = try? statsClient.getDailyStats()
    async let todaysSessionsResult = try? healthKitClient.getSessions(now)
    let (stats, todaysSessions) = await (statsResult, todaysSessionsResult)

    if let stats {
      await send(.updateStats(stats), animation: .nice)
    }
    if let todaysSessions {
      await send(.updateTodaysSessions(todaysSessions), animation: .nice)
    }
    if let selectedDay {
      if Calendar.current.isDate(selectedDay, inSameDayAs: now), let todaysSessions {
        await send(.updateSelectedDaySessions(selectedDay, todaysSessions), animation: .nice)
      } else if let sessions = try? await healthKitClient.getSessions(selectedDay) {
        await send(.updateSelectedDaySessions(selectedDay, sessions), animation: .nice)
      }
    }
  }
}

struct NewStatsView: View {
  @ObserveInjection var inject
  @Bindable var store: StoreOf<StatsFeature>

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
            practicedTodayButton(stats: stats)

            if store.isTodayExpanded {
              todaysSessionRows
                .transition(.blurReplace)
            }
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
    .sensoryFeedback(.selection, trigger: store.isTodayExpanded)
    .font(.system(.headline))
    .enableInjection()
  }

  private func practicedTodayButton(stats: DailyStats) -> some View {
    Button {
      store.send(.toggleTodayExpanded, animation: .nice)
    } label: {
      HStack(spacing: 6) {
        (Text("You practiced for ")
          .foregroundStyle(.secondary) + formatTime(stats.totalMinutesToday)
          + Text(" today")
          .foregroundStyle(.secondary))
          .contentTransition(.numericText(value: Double(stats.totalMinutesToday)))

        Image(systemName: "chevron.down")
          .font(.caption2.bold())
          .foregroundStyle(.secondary.opacity(0.7))
          .rotationEffect(.degrees(store.isTodayExpanded ? 180 : 0))
      }
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .transition(.blurReplace)
  }

  private var todaysSessionRows: some View {
    MindfulSessionRows(store: store, sessions: store.todaysSessions)
  }

  fileprivate func formatTime(_ minutes: Double) -> Text {
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

/// Editable rows for a day's mindful sessions, shared between the home
/// header's "today" expansion and the streak page's day selection.
struct MindfulSessionRows: View {
  @Bindable var store: StoreOf<StatsFeature>
  let sessions: [MindfulSessionSample]

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      ForEach(sessions) { session in
        sessionRow(session)
      }
    }
    .padding(.leading, 2)
    .animation(.nice, value: sessions)
    .animation(.nice, value: store.editingSessionID)
  }

  @ViewBuilder
  private func sessionRow(_ session: MindfulSessionSample) -> some View {
    let isEditing = store.editingSessionID == session.id

    HStack(spacing: 16) {
      Text(session.startDate, format: .dateTime.hour().minute())
        .foregroundStyle(.secondary)
        .monospacedDigit()
        .frame(width: 84, alignment: .leading)

      /// One persistent view whether static or editing: only the number's
      /// tint and value change, so entering and leaving edit mode never
      /// replaces the row.
      Button {
        store.send(.beginEditingSession(session.id), animation: .nice)
      } label: {
        durationText(for: session, isEditing: isEditing)
          .monospacedDigit()
          .contentTransition(.numericText(value: displayedDurationValue(for: session, isEditing: isEditing)))
          .animation(.nice, value: isEditing)
          .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .disabled(!session.isEditable)

      Spacer()

      if session.isEditable {
        let isPendingDeletion = store.pendingDeletionID == session.id

        Button {
          store.send(.deleteSession(session.id), animation: .nice)
        } label: {
          Group {
            if isPendingDeletion {
              Text("delete?")
            } else {
              Image(systemName: "xmark")
            }
          }
            .font(.caption.bold())
            .foregroundStyle(isPendingDeletion ? Color.red : Color.secondary.opacity(0.7))
            .padding(8)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .padding(-8)
        .animation(.nice, value: isPendingDeletion)
      }
    }
    .font(.system(.subheadline).weight(.medium))
    .transition(.blurReplace)
  }

  /// Floored whole minutes for compact display; sub-minute sits show seconds.
  private func durationText(for session: MindfulSessionSample, isEditing: Bool) -> Text {
    if isEditing {
      let minutes = store.editedMinutes ?? max(1, session.minutes)
      return Text("\(minutes)").foregroundStyle(Color.pink)
        + Text(" min").foregroundStyle(.secondary)
    }

    if session.durationSeconds < 60 {
      return Text("\(session.durationSeconds)").foregroundStyle(Color.primary)
        + Text(" sec").foregroundStyle(.secondary)
    }

    return Text("\(session.minutes)").foregroundStyle(Color.primary)
      + Text(" min").foregroundStyle(.secondary)
  }

  private func displayedDurationValue(for session: MindfulSessionSample, isEditing: Bool) -> Double {
    if isEditing {
      return Double(store.editedMinutes ?? max(1, session.minutes))
    }
    return Double(session.durationSeconds < 60 ? session.durationSeconds : session.minutes)
  }
}

#Preview("StatsView") {
  let store = Store(initialState: StatsFeature.State()) {
    StatsFeature()
  } withDependencies: {
    $0.statsClient.getDailyStats = {
      sampleDailyStats(totalMinutesToday: 0)
    }
  }
  NewStatsView(store: store)
}
