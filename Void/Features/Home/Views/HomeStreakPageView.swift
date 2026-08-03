import ComposableArchitecture
import SwiftUI

struct HomeStreakPageView: View {
  let store: StoreOf<HomeReducer>

  private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 7)

  @Environment(\.colorScheme) private var colorScheme

  private var backgroundColor: Color {
    colorScheme == .dark ? .black : .white
  }

  var body: some View {
    Group {
      if let stats = store.stats.dailyStats {
        streakContent(stats: stats)
      } else {
        ProgressView()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(backgroundColor)
  }

  private func streakContent(stats: DailyStats) -> some View {
    VStack(alignment: .leading, spacing: 24) {
      if stats.streak > 0 {
        header(stats: stats)
          .transition(.blurReplace)
      }

      practiceGrid(stats: stats)

      if let selectedDay = store.stats.selectedDay {
        selectedDayDetail(selectedDay)
          .transition(.blurReplace)
      } else {
        Text("Your last six weeks of practice.")
          .font(.system(.headline))
          .fontWeight(.medium)
          .foregroundStyle(.secondary)
          .transition(.blurReplace)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding(.horizontal, 32)
    .padding(.top, 40)
    .padding(.bottom, 28)
    .animation(.nice, value: store.stats.selectedDay)
    .sensoryFeedback(.selection, trigger: store.stats.selectedDay)
  }

  private func header(stats: DailyStats) -> some View {
    (Text(String(stats.streak))
      + Text(" day streak").foregroundStyle(.secondary))
      .font(.system(.headline))
      .fontWeight(.medium)
      .contentTransition(.numericText(value: Double(stats.streak)))
  }

  private func practiceGrid(stats: DailyStats) -> some View {
    // Chronological: oldest day top-left, today bottom-right.
    let days = Array(stats.recentPracticeDays.reversed())
    let todayDate = days.last?.date

    return LazyVGrid(columns: columns, spacing: 10) {
      ForEach(days) { day in
        dayCell(
          day,
          isToday: day.date == todayDate,
          isSelected: store.stats.selectedDay == day.date
        )
      }
    }
  }

  private func dayCell(_ day: PracticeDay, isToday: Bool, isSelected: Bool) -> some View {
    Button {
      store.send(.stats(.selectDay(day.date)), animation: .nice)
    } label: {
      tileShape(for: day)
        .aspectRatio(1, contentMode: .fit)
        .brightness(isToday ? 0.12 : (isSelected ? 0.1 : 0))
        .shadow(color: tileGlow(for: day, isToday: isToday, isSelected: isSelected), radius: 7)
        .scaleEffect(isSelected ? 1.12 : 1)
        .animation(.nice, value: isSelected)
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
  }

  @ViewBuilder
  private func tileShape(for day: PracticeDay) -> some View {
    let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)

    if #available(iOS 26.0, *) {
      shape
        .fill(.clear)
        .glassEffect(.regular.tint(cellColor(for: day)), in: shape)
    } else {
      shape
        .fill(cellColor(for: day))
    }
  }

  @ViewBuilder
  private func selectedDayDetail(_ day: Date) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(spacing: 6) {
        Text(day, format: .dateTime.weekday(.wide).month().day())
          .font(.system(.headline))
          .fontWeight(.medium)

        Spacer()

        Button {
          store.send(.stats(.selectDay(nil)), animation: .nice)
        } label: {
          Image(systemName: "xmark")
            .font(.caption.bold())
            .foregroundStyle(.secondary.opacity(0.7))
            .padding(8)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .padding(-8)
      }

      if store.stats.selectedDaySessions.isEmpty {
        Text("No sits this day.")
          .font(.system(.subheadline).weight(.medium))
          .foregroundStyle(.secondary)
          .transition(.blurReplace)
      } else {
        MindfulSessionRows(
          store: store.scope(state: \.stats, action: \.stats),
          sessions: store.stats.selectedDaySessions
        )
      }
    }
    .animation(.nice, value: store.stats.selectedDaySessions)
  }

  private func tileGlow(for day: PracticeDay, isToday: Bool, isSelected: Bool) -> Color {
    if isToday {
      if day.isInCurrentStreak {
        return .pink.opacity(0.6)
      }
      if day.didMeditate {
        return .pink.opacity(0.4)
      }
      return colorScheme == .dark ? .white.opacity(0.3) : .black.opacity(0.2)
    }

    if isSelected {
      return colorScheme == .dark ? .white.opacity(0.25) : .black.opacity(0.2)
    }

    return .clear
  }

  private func cellColor(for day: PracticeDay) -> Color {
    if day.isInCurrentStreak {
      return colorScheme == .dark ? Color.pink.opacity(0.88) : Color.red.opacity(0.82)
    }

    if day.didMeditate {
      return colorScheme == .dark
        ? Color(red: 0.47, green: 0.11, blue: 0.16)
        : Color(red: 0.80, green: 0.32, blue: 0.39).opacity(0.9)
    }

    return colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.08)
  }
}

#Preview("Streak Page") {
  let store = Store(initialState: HomeReducer.State()) {
    HomeReducer()
  } withDependencies: {
    $0.statsClient.getDailyStats = {
      sampleDailyStats()
    }
  }

  HomeStreakPageView(store: store)
}
