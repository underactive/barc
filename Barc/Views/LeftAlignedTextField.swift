import SwiftUI
import AppKit

// MARK: - Left-Aligned TextField (fixes macOS Form right-alignment issue)

struct LeftAlignedTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var font: NSFont = .systemFont(ofSize: 12)
    var isEnabled: Bool = true
    var onSubmit: (() -> Void)? = nil

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.placeholderString = placeholder
        textField.font = font
        textField.alignment = .left
        textField.bezelStyle = .roundedBezel
        textField.delegate = context.coordinator
        textField.lineBreakMode = .byTruncatingTail
        textField.cell?.truncatesLastVisibleLine = true
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.isEnabled = isEnabled
        nsView.alignment = .left
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: LeftAlignedTextField

        init(_ parent: LeftAlignedTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit?()
                return true
            }
            return false
        }
    }
}

