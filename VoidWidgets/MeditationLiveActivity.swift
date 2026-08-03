import ActivityKit
import SwiftUI
import WidgetKit

struct MeditationLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: MeditationActivityAttributes.self) { context in
      lockScreenView(state: context.state)
        .activityBackgroundTint(.black.opacity(0.85))
        .activitySystemActionForegroundColor(.pink)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          statusLabel(state: context.state)
            .padding(.leading, 8)
        }
        DynamicIslandExpandedRegion(.trailing) {
          elapsedText(state: context.state)
            .font(.system(.title3, weight: .heavy).width(.expanded))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.trailing, 8)
        }
      } compactLeading: {
        Circle()
          .fill(.pink)
          .frame(width: 10, height: 10)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } compactTrailing: {
        elapsedText(state: context.state)
          .font(.system(.caption, weight: .bold))
          .monospacedDigit()
          .foregroundStyle(.white)
          .frame(maxWidth: 44)
      } minimal: {
        Circle()
          .fill(.pink)
          .frame(width: 10, height: 10)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      .keylineTint(.pink)
    }
  }

  private func lockScreenView(state: MeditationActivityAttributes.ContentState) -> some View {
    HStack(alignment: .firstTextBaseline) {
      statusLabel(state: state)

      Spacer()

      elapsedText(state: state)
        .font(.system(.title2, weight: .heavy).width(.expanded))
        .monospacedDigit()
        .foregroundStyle(.white)
    }
    .padding(20)
  }

  private func statusLabel(state: MeditationActivityAttributes.ContentState) -> some View {
    HStack(spacing: 8) {
      Circle()
        .fill(state.isPaused ? Color.pink.opacity(0.4) : .pink)
        .frame(width: 10, height: 10)

      Text(state.isPaused ? "Paused" : "Meditating")
        .font(.headline.weight(.medium))
        .foregroundStyle(.white.opacity(0.6))
    }
  }

  private func elapsedText(state: MeditationActivityAttributes.ContentState) -> Text {
    if let pausedElapsedSeconds = state.pausedElapsedSeconds {
      let minutes = pausedElapsedSeconds / 60
      let seconds = pausedElapsedSeconds % 60
      return Text(String(format: "%d:%02d", minutes, seconds))
    }
    return Text(state.startDate, style: .timer)
  }
}
