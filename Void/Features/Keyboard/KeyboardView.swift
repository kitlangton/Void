import Foundation
import Inject
import SwiftUI

@Observable
class KeyboardManager {
  static let shared = KeyboardManager()

  var isVisible = false
  var keyboardHeight: CGFloat = 295

  var numberBinding: Binding<Int?>?
  var handleDismiss: (() -> Void)?
}

struct KeyboardAdaptive: ViewModifier {
  @ObserveInjection var inject
  @State var keyboardManager = KeyboardManager.shared

  var bottomPadding: CGFloat {
    keyboardManager.isVisible ? keyboardManager.keyboardHeight : 0
  }

  func body(content: Content) -> some View {
    content
      .frame(maxHeight: .infinity)
      .safeAreaInset(edge: .bottom) {
        if keyboardManager.isVisible {
          KeyboardView()
            .transition(.move(edge: .bottom).combined(with: .blurReplace).combined(with: .opacity))
        }
      }
      .enableInjection()
  }
}

extension View {
  func keyboardAdaptive() -> some View {
    modifier(KeyboardAdaptive())
  }

  func digitKeyboard(binding: Binding<Int?>, handleDismiss: @escaping () -> Void = {}) -> some View {
    onAppear {
      KeyboardManager.shared.numberBinding = binding
      KeyboardManager.shared.handleDismiss = handleDismiss
    }
  }
}

enum ButtonType: Equatable, Hashable {
  case number(Int)
  case delete
  case done
}

let buttons: [[ButtonType]] = [
  [.number(1), .number(2), .number(3)],
  [.number(4), .number(5), .number(6)],
  [.number(7), .number(8), .number(9)],
  [.delete, .number(0), .done],
]

extension KeyboardView {
  struct KeyboardButton: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
      var opacity: CGFloat {
        isEnabled ? 1 : 0.7
      }

      configuration.label
        .font(.title2.bold())
        .frame(maxWidth: .infinity)
        .frame(height: 60)
        .background(.ultraThinMaterial)
        .overlay(
          Color.white.opacity(configuration.isPressed ? 0.2 : 0)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .opacity(opacity)
        .scaleEffect(configuration.isPressed ? 0.95 : 1)
        .animation(.spring(duration: 0.3), value: isEnabled)
    }
  }
}

struct KeyboardView: View {
  @ObserveInjection var inject
  @State var keyboardManager = KeyboardManager.shared
  @State var currentInput: [Int] = []

  var deleteButton: some View {
    Button {
      if !currentInput.isEmpty {
        currentInput.removeLast()
      }
    } label: {
      Image(systemName: "delete.backward.fill")
    }
    .buttonStyle(KeyboardButton())
    .disabled(currentInput.isEmpty)
  }

  var doneButton: some View {
    Button {
      withAnimation(.nice) {
        keyboardManager.isVisible = false
        keyboardManager.handleDismiss?()
      }
    } label: {
      Image(systemName: "checkmark")
    }
    .buttonStyle(KeyboardButton())
  }

  func digitButton(for digit: Int) -> some View {
    Button {
      if currentInput.count < 3 {
        currentInput.append(digit)
      }
    } label: {
      Text("\(digit)")
    }
    .buttonStyle(KeyboardButton())
    .disabled(currentInput.count >= 3)
  }

  var body: some View {
    Grid(horizontalSpacing: 8, verticalSpacing: 8) {
      ForEach(buttons, id: \.self) { row in
        GridRow {
          ForEach(row, id: \.self) { buttonType in
            switch buttonType {
            case .delete:
              deleteButton
            case let .number(digit):
              digitButton(for: digit)
            case .done:
              doneButton
            }
          }
        }
      }
    }
    .onChange(of: currentInput) {
      let numberString = currentInput.map(String.init).joined()
      let number: Int? = numberString.isEmpty ? nil : Int(numberString)
      withAnimation(.nice) {
        KeyboardManager.shared.numberBinding?.wrappedValue = number
      }
    }
    .sensoryFeedback(.selection, trigger: currentInput)
    .padding()
    .frame(maxWidth: .infinity)
    .frame(height: 295)
    .enableInjection()
  }
}