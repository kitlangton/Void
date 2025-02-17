//
//  LogoView.swift
//  Void
//
//  Created by Kit Langton on 11/18/24.
//

import Inject
import Pow
import SwiftUI

struct LogoView: View {
  @ObserveInjection var inject

  var numberOfRays = 10
  var color: Color = .pink
  var rayWidthMultiplier: CGFloat = 0.5
  var rotation: Angle = .degrees(18)

  var body: some View {
    StarburstShape(numberOfRays: numberOfRays, rayWidthMultiplier: rayWidthMultiplier)
      .fill(color)
      .aspectRatio(1, contentMode: .fit)
      .rotationEffect(rotation)
      .enableInjection()
  }
}

struct StarburstShape: Shape {
  let numberOfRays: Int
  var rayWidthMultiplier: CGFloat

  // Make the shape animatable
  var animatableData: CGFloat {
    get { rayWidthMultiplier }
    set { rayWidthMultiplier = newValue }
  }

  func path(in rect: CGRect) -> Path {
    var path = Path()

    let center = CGPoint(x: rect.midX, y: rect.midY)
    let radius = min(rect.width, rect.height) / 2

    // Calculate the angle between each ray
    let angleIncrement = (2 * .pi) / Double(numberOfRays)
    let rayWidth = angleIncrement * rayWidthMultiplier

    for i in 0 ..< numberOfRays {
      let centerAngle = Double(i) * angleIncrement

      // Create a thinner triangular ray
      let rayPath = Path { p in
        p.move(to: center)

        // Calculate points for the thin triangle
        let leftAngle = centerAngle - rayWidth / 2
        let rightAngle = centerAngle + rayWidth / 2

        let x1 = center.x + radius * cos(leftAngle)
        let y1 = center.y + radius * sin(leftAngle)

        let x2 = center.x + radius * cos(rightAngle)
        let y2 = center.y + radius * sin(rightAngle)

        p.addLine(to: CGPoint(x: x1, y: y1))
        p.addLine(to: CGPoint(x: x2, y: y2))
        p.closeSubpath()
      }

      path.addPath(rayPath)
    }

    return path
  }
}

// Example of how to use the animated logo
struct AnimatedLogoExample: View {
  @State var isOpen = false
  @State var rotation = 0.0

  var isAnimating: Bool

  var rayWidth: CGFloat { isOpen ? 0.5 : 1 }
  var scale: CGFloat { isOpen ? 1 : 0.1 }
  var color: Color { isOpen ? .pink : .primary }
  var blur: CGFloat { isOpen ? 0 : 5 }

  var body: some View {
    VStack {
      LogoView(
        color: color,
        rayWidthMultiplier: rayWidth,
        rotation: .degrees(rotation)
      )
      .changeEffect(.glow, value: isOpen)
      .blur(radius: blur)
      .scaleEffect(scale)
      .contentShape(.rect)
    }.task(id: isAnimating) {
      if isAnimating {
        while isAnimating {
          animate()
          try? await Task.sleep(for: .seconds(1))
        }
      }
    }
  }

  func animate() {
    withAnimation(.spring(duration: 0.5, bounce: 0.3)) {
      isOpen.toggle()
    }

    withAnimation(.spring(duration: 1.5)) {
      rotation += 180
    }
  }
}

struct RotatingLogoView: View {
  @State private var rotation = 0.0

  var isActive: Bool = true

  var body: some View {
    LogoView(
      color: .pink,
      rayWidthMultiplier: 0.5,
      rotation: .degrees(rotation)
    )
    .drawingGroup()
    .task(id: isActive) {
      if isActive {
        withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
          rotation = 360
        }
      } else {
        withAnimation(.spring) {
          rotation = 0
        }
      }
    }
  }
}

#Preview {
  AnimatedLogoExample(isAnimating: true)
    .frame(width: 100, height: 100)
    .preferredColorScheme(.dark)
}
