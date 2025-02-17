import Inject
import Pow
import SwiftUI

struct UpdatingDouble: View, Animatable {
  var double: Double

  var animatableData: Double {
    get { double }
    set { double = newValue }
  }

  var body: some View {
    Text("\(animatableData)")
  }
}

struct Rotating: ViewModifier, Animatable {
  var rotationSpeed: CGFloat

  @State var rotation: Double = 0

  var animatableData: CGFloat {
    get { rotationSpeed }
    set { rotationSpeed = newValue }
  }

  func body(content: Content) -> some View {
    TimelineView(.animation) { timeline in
      content
        .rotationEffect(.degrees(rotation))
        .onChange(of: timeline.date) {
          rotation += 1 * rotationSpeed
        }
    }
  }
}

extension View {
  func rotating(speed: CGFloat) -> some View {
    modifier(Rotating(rotationSpeed: speed))
  }
}

struct MovingLogoView: View {
  init(phase: Phase) {
    self.phase = phase
    switch phase {
    case .closed,
         .burst: rotationSpeed = 0
    case let .spinning(speed): rotationSpeed = speed
    }
  }

  enum Phase: Equatable, Hashable {
    case closed
    case burst
    case spinning(speed: CGFloat)
  }

  @ObserveInjection var inject

  var phase: Phase
  @State var rotationSpeed: CGFloat

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
      .rotating(speed: rotationSpeed)
      .animation(.nice) {
        $0.scaleEffect(scale)
      }
      .task(id: phase) {
        switch phase {
        case .closed:
          withAnimation(.spring(duration: 0.2)) {
            rotationSpeed = 10
          }
          withAnimation(.easeOut(duration: 2)) {
            rotationSpeed = 0
          }
        case let .spinning(speed):
          withAnimation(.spring) {
            rotationSpeed = speed
          }
        case .burst:
          withAnimation(.spring(duration: 0.2)) {
            rotationSpeed = 10
          }
          withAnimation(.easeOut(duration: 3)) {
            rotationSpeed = 0.5
          }
        }
      }
      .drawingGroup()
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
