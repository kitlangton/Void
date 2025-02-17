import SwiftUI
import Inject

struct NumberInputView: View {
    @ObserveInjection var inject
    @State var keyboardManager = KeyboardManager.shared

    var binding: Binding<Int?>
    var unit: String
    var handleDismiss: () -> Void

    @State var value: Int?

    var pluralizedUnit: String {
        value == 1 ? unit : "\(unit)s"
    }

    var body: some View {
        var text: Text {
            if let value = value {
                return Text("\(value)") + Text(" \(pluralizedUnit)").foregroundStyle(.secondary)
            } else {
                return Text("_").foregroundStyle(.secondary)
            }
        }

        text
            .contentTransition(.numericText(value: Double(value ?? 0)))
            .foregroundStyle(.primary)
            .font(.system(.title2).weight(.bold))
            .digitKeyboard(
                binding: $value,
                handleDismiss: handleDismiss
            )
            .onAppear {
                withAnimation(.nice) {
                    keyboardManager.isVisible = true
                }
            }
            .onChange(of: value) {
                withAnimation(.nice) {
                    binding.wrappedValue = value
                }
            }
            .enableInjection()
    }
}

#Preview {
    @Previewable @State var value: Int? = 5

    return NumberInputView(
        binding: .init(
            get: { value },
            set: { value = $0 }
        ),
        unit: "minute",
        handleDismiss: {}
    )
}
