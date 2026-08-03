import Inject
import Pow
import SwiftUI

struct MovingLogoView: View {
  enum Phase: Equatable, Hashable {
    case closed
    case burst
    case spinning(speed: CGFloat)
  }

  @ObserveInjection var inject
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var phase: Phase
  @State private var rotation = 0.0

  var color: Color {
    switch phase {
    case .closed: .primary
    case .burst: .pink
    case .spinning: .pink
    }
  }

  var rayWidthMultiplier: CGFloat {
    switch phase {
    case .closed: 1
    case .burst: 0.5
    case .spinning: 0.5
    }
  }

  var scale: CGFloat {
    switch phase {
    case .closed: 0.1
    case .burst: 1
    case .spinning: 1
    }
  }

  var body: some View {
    StarburstShape(numberOfRays: 10, rayWidthMultiplier: rayWidthMultiplier)
      .fill(color)
      .animation(.spring, value: rayWidthMultiplier)
      .aspectRatio(1, contentMode: .fit)
      .drawingGroup()
      .rotationEffect(.degrees(rotation))
      .animation(.nice) {
        $0.scaleEffect(scale)
      }
      .task(id: reduceMotion ? nil : phase) {
        guard !reduceMotion else {
          rotation = 0
          return
        }

        switch phase {
        case .closed:
          withAnimation(.easeOut(duration: 2)) {
            rotation += 720
          }
        case let .spinning(speed):
          guard speed > 0 else { return }
          withAnimation(.linear(duration: 6 / speed).repeatForever(autoreverses: false)) {
            rotation += 360
          }
        case .burst:
          withAnimation(.easeOut(duration: 3)) {
            rotation += 1080
          }
        }
      }
      .changeEffect(
        .glow(color: .white.opacity(0.5)),
        value: phase == .burst,
        isEnabled: phase != .burst
      )
      .enableInjection()
  }
}

#Preview {
  @Previewable @State var phase: MovingLogoView.Phase = .closed

  VStack(spacing: 20) {
    MovingLogoView(phase: phase)
      .frame(width: 100, height: 100)

    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
      Button("Spinning") {
        phase = .spinning(speed: 1)
      }
      .buttonStyle(.bordered)
      .tint(phase == .spinning(speed: 1) ? .accentColor : .secondary)

      Button("Spinning (Fast)") {
        phase = .spinning(speed: 5)
      }
      .buttonStyle(.bordered)
      .tint(phase == .spinning(speed: 5) ? .accentColor : .secondary)

      Button("Burst") {
        phase = .burst
      }
      .buttonStyle(.bordered)
      .tint(phase == .burst ? .accentColor : .secondary)

      Button("Closed") {
        phase = .closed
      }
      .buttonStyle(.bordered)
      .tint(phase == .closed ? .accentColor : .secondary)
    }
  }
}
