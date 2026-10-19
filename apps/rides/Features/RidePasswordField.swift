import SwiftUI
import UIKit

struct RidePasswordField: UIViewRepresentable {
    @Binding var text: String
    @Binding var focused: Bool
    var secure: Bool
    var creating: Bool
    var returnKey: UIReturnKeyType
    var onSubmit: () -> Void

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.placeholder = "Enter your password"
        field.font = .systemFont(ofSize: 16)
        field.tintColor = .black
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.smartDashesType = .no
        field.smartQuotesType = .no
        field.clearsOnBeginEditing = false
        field.accessibilityIdentifier = "auth.password"
        field.accessibilityLabel = "Password"
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed), for: .editingChanged)
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        if field.isSecureTextEntry != secure {
            let start = field.selectedTextRange.map { field.offset(from: field.beginningOfDocument, to: $0.start) }
            let end = field.selectedTextRange.map { field.offset(from: field.beginningOfDocument, to: $0.end) }
            field.isSecureTextEntry = secure
            field.text = text
            if let start, let end,
               let beginning = field.position(from: field.beginningOfDocument, offset: start),
               let ending = field.position(from: field.beginningOfDocument, offset: end) {
                field.selectedTextRange = field.textRange(from: beginning, to: ending)
            }
        } else if field.text != text {
            field.text = text
        }
        let contentType: UITextContentType = creating ? .newPassword : .password
        if field.textContentType != contentType { field.textContentType = contentType }
        if field.returnKeyType != returnKey { field.returnKeyType = returnKey }
        field.isEnabled = context.environment.isEnabled
        if focused && !field.isFirstResponder { field.becomeFirstResponder() }
        else if !focused && field.isFirstResponder { field.resignFirstResponder() }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: RidePasswordField

        init(_ parent: RidePasswordField) { self.parent = parent }

        @objc func changed(_ field: UITextField) { parent.text = field.text ?? "" }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            if !parent.focused { parent.focused = true }
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            if parent.focused { parent.focused = false }
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onSubmit()
            return false
        }
    }
}
