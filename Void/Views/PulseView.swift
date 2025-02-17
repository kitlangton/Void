
import Inject
import SwiftUI

@Observable
class PulseManager {
  var pulses: Set<UUID> = []

  func addPulse() -> UUID {
    let id = UUID()
    withAnimation {
      pulses.insert(id)
      ()
    }
    return id
  }

  func removePulse(_ id: UUID) {
    pulses.remove(id)
  }
}

struct PulseModifier<A: Equatable>: ViewModifier {
  @State var pulseManager = PulseManager()

  var trigger: A
  var direction: PulseView.Direction

  func body(content: Content) -> some View {
    content
      .overlay {
        ZStack {
          Color.clear

          ForEach(Array(pulseManager.pulses), id: \.self) { id in
            PulseView(direction: direction)
              .drawingGroup()
              .id(id)
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .ignoresSafeArea()
      }
      .onChange(of: trigger) {
        let id = pulseManager.addPulse()
        Task {
          try? await Task.sleep(for: .seconds(6))
          pulseManager.removePulse(id)
        }
      }
  }
}

extension View {
  func pulsing<A: Equatable>(_ trigger: A, direction: PulseView.Direction = .up) -> some View {
    modifier(PulseModifier(trigger: trigger, direction: direction))
  }
}

struct PulseView: View {
  enum Direction {
    case up
    case down
  }

  enum Phase {
    case bottom
    case top

    func opposite() -> Phase {
      switch self {
      case .bottom: return .top
      case .top: return .bottom
      }
    }
  }

  var direction: Direction = .up
  let height: CGFloat = 700

  var stops: [Gradient.Stop] {
    switch (phase, direction) {
    case (.bottom, .up):
      return [
        .init(color: .clear, location: 0.3),
        .init(color: .white.opacity(0.5), location: 0.9),
        .init(color: .clear, location: 1),
      ]
    case (.top, .up):
      return [
        .init(color: .clear, location: 0),
        .init(color: .white.opacity(0.2), location: 0.1),
        .init(color: .clear, location: 0.7),
      ]
    case (.top, .down):
      return [
        .init(color: .clear, location: 0),
        .init(color: .white.opacity(0.5), location: 0.5),
        .init(color: .clear, location: 0.6),
      ]
    case (.bottom, .down):
      return [
        .init(color: .clear, location: 0),
        .init(color: .white.opacity(0.2), location: 0.1),
        .init(color: .clear, location: 0.7),
      ]
    }
  }

  // a blurred white linear gradient, 100px height
  var gradientView: some View {
    LinearGradient(
      stops: stops,
      startPoint: .top,
      endPoint: .bottom
    )
    .frame(height: height)
    .padding(.horizontal, -300)
    .blur(radius: 150)
  }

  @State var phase: Phase = .bottom

  init(direction: Direction) {
    self.direction = direction
    _phase = State(wrappedValue: direction == .up ? .bottom : .top)
  }

  var body: some View {
    GeometryReader { proxy in
      let offsetY = switch phase {
      case .bottom: proxy.size.height + (direction == .down ? height : 0)
      case .top: -proxy.size.height - (direction == .up ? height : -200)
      }
      gradientView
        .offset(y: offsetY)
    }
    .onAppear {
      withAnimation(.easeOut(duration: 1.3)) {
        phase = phase.opposite()
      }
    }
  }
}

#Preview {
  @Previewable @State var trigger = 0
  @Previewable @State var direction: PulseView.Direction = .up

  VStack {
    Picker("Direction", selection: $direction) {
      Text("Up").tag(PulseView.Direction.up)
      Text("Down").tag(PulseView.Direction.down)
    }
    .pickerStyle(.segmented)
    Text("Trigger: \(trigger)")
    Button("Trigger") {
      trigger += 1
    }
  }
  .frame(maxWidth: .infinity, maxHeight: .infinity)
  .pulsing(trigger, direction: direction)
}
