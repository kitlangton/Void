//
//  MeditationTimerView.swift
//  Void
//
//  Created by Kit Langton on 12/1/24.
//

import ComposableArchitecture
import Inject
import Pow
import SwiftUI

struct MeditationTimerView: View {
  @ObserveInjection var inject
  @Bindable var store: StoreOf<MeditationTimerFeature>

  var isActive: Bool {
    !store.meditationState.isPaused
  }

  var body: some View {
    Button {
      store.send(.pausePlay, animation: .nice)
    } label: {
      timeView
        .opacity(isActive ? 1 : 0.7)
        .scaleEffect(isActive ? 1 : 0.98)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal)
        .animation(.nice, value: store.elapsedSeconds)
        .animation(.nice, value: store.settings.durationMinutes)
        .overlay(alignment: .bottom) {
          TapToPauseResumeText(isPaused: store.isPaused)
            .offset(y: 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 180)
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .drawingGroup()
    .padding(-120)
    .task(id: store.isPaused) {
      if !store.isPaused {
        await store.send(.start).finish()
      }
    }
    .sensoryFeedback(.selection, trigger: store.isPaused)
    .offset(y: store.expandedSection != nil ? -100 : 0)
    .enableInjection()
  }

  private var timeView: some View {
    displayTime
      .font(.system(size: 80, weight: .heavy).width(.expanded))
      .monospacedDigit()
      .contentTransition(.numericText(value: Double(store.elapsedSeconds)))
      .animation(.nice, value: store.elapsedSeconds)
  }

  private var displayTime: Text {
    if let remainingTime = store.remainingTime {
      return formatTimeWithStyle(Double(remainingTime))
    } else {
      return formatTimeWithStyle(Double(store.elapsedSeconds))
    }
  }

  private func formatTimeWithStyle(_ timeInterval: TimeInterval) -> Text {
    let minutes = Int(timeInterval) / 60
    let seconds = Int(timeInterval) % 60
    let totalSeconds = minutes * 60 + seconds
    let primaryStyle: Color = store.isPaused ? .secondary : .primary
    let grayStyle: Color = .secondary.opacity(0.35)

    // If total value is less than 10 seconds, all zeros should be grey
    if totalSeconds < 10 {
      return Text("0:0").foregroundStyle(grayStyle) + Text("\(seconds)").foregroundStyle(primaryStyle)
    }
    // If total value is less than 60 seconds, first two chars should be grey
    else if totalSeconds < 60 {
      return Text("0:").foregroundStyle(grayStyle)
        + Text("\(String(format: "%02d", seconds))").foregroundStyle(primaryStyle)
    }
    // If total value is less than 600 seconds (10 minutes), show minutes normally
    else {
      return Text("\(minutes)").foregroundStyle(primaryStyle)
        + Text(":").foregroundStyle(primaryStyle)
        + Text("\(String(format: "%02d", seconds))").foregroundStyle(primaryStyle)
    }
  }
}


struct TapToPauseResumeText: View {
  var isPaused: Bool
  @State var isVisible = false

  var body: some View {
    Text(isPaused ? "tap to resume" : "tap to pause")
      .contentTransition(.numericText(countsDown: false))
      .font(.body.weight(.medium))
      .foregroundStyle(.secondary)
      .opacity(isVisible ? 1 : 0)
      .changeEffect(.glow(color: .white), value: isPaused)
      .task(id: isPaused) {
        try? await animateInOut()
      }
  }

  func animateInOut() async throws {
    if !isPaused {
      withAnimation(.spring(duration: 2)) {
        isVisible = true
      }
      try await Task.sleep(for: .seconds(3))
      withAnimation(.spring(duration: 8)) {
        isVisible = false
      }
    } else {
      withAnimation(.spring) {
        isVisible = true
      }
    }
  }
}

#Preview {
  let meditationState = MeditationState(now: Date())
  let state = MeditationTimerFeature.State(meditationState: Shared(value: meditationState), now: Date())
  MeditationTimerView(store: .init(initialState: state) {
    MeditationTimerFeature()
  })
}
