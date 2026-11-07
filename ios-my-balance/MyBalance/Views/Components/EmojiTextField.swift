import SwiftUI
import UIKit

/// Text field that opens the system emoji keyboard and keeps only the last emoji typed.
struct EmojiTextField: UIViewRepresentable {
    @Binding var emoji: String
    @Binding var isFocused: Bool

    func makeUIView(context: Context) -> EmojiUITextField {
        let tf = EmojiUITextField()
        tf.delegate = context.coordinator
        tf.tintColor = .clear
        tf.textAlignment = .center
        tf.font = .systemFont(ofSize: 1)
        tf.textColor = .clear
        tf.autocorrectionType = .no
        tf.spellCheckingType = .no
        tf.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        return tf
    }

    func updateUIView(_ tf: EmojiUITextField, context: Context) {
        context.coordinator.parent = self
        DispatchQueue.main.async {
            if isFocused, !tf.isFirstResponder { tf.becomeFirstResponder() }
            if !isFocused, tf.isFirstResponder { tf.resignFirstResponder() }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: EmojiTextField
        init(_ parent: EmojiTextField) { self.parent = parent }

        @objc func changed(_ tf: UITextField) {
            let text = tf.text ?? ""
            if let last = text.last(where: { $0.isEmoji }) {
                parent.emoji = String(last)
            }
            tf.text = ""
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            if !parent.isFocused { parent.isFocused = true }
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            if parent.isFocused { parent.isFocused = false }
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }
    }
}

final class EmojiUITextField: UITextField {
    override var textInputContextIdentifier: String? { "" }
    override var textInputMode: UITextInputMode? {
        UITextInputMode.activeInputModes.first { $0.primaryLanguage == "emoji" } ?? super.textInputMode
    }
}

extension Character {
    /// True for characters rendered as emoji (excludes plain digits, #, *).
    var isEmoji: Bool {
        guard let first = unicodeScalars.first else { return false }
        if first.properties.isEmojiPresentation { return true }
        return first.properties.isEmoji && (unicodeScalars.count > 1 || first.value > 0x238C)
    }
}
