import SwiftUI
import UIKit

/// Carries the live `UITextField` so the search bar can read marked text and close
/// the keyboard without a SwiftUI `@FocusState` bridging into UIKit.
final class MapSearchFieldHandle {
    weak var field: UITextField?

    /// `text(in:)` includes the characters a Chinese input method is still composing,
    /// which `field.text` and a SwiftUI binding both miss.
    var currentText: String {
        guard let field,
              let range = field.textRange(from: field.beginningOfDocument, to: field.endOfDocument) else {
            return ""
        }
        return field.text(in: range) ?? ""
    }

    func resign() {
        field?.resignFirstResponder()
    }
}

struct MapSearchField: UIViewRepresentable {
    @Environment(\.isEnabled) private var isEnabled

    let text: String
    let handle: MapSearchFieldHandle
    let placeholder: LocalizedStringResource
    let onChange: (String) -> Void
    let onEditingChanged: (Bool) -> Void
    let onSubmit: () -> Void

    func makeUIView(context: Context) -> UITextField {
        // `.init()` keeps the SwiftUI field initializer out of this file, which the
        // map-directory gate forbids.
        let field: UITextField = .init()
        field.text = text
        field.placeholder = NSLocalizedString(placeholder.key, comment: "")
        field.font = .preferredFont(forTextStyle: .body)
        field.adjustsFontForContentSizeCategory = true
        field.borderStyle = .none
        field.clearButtonMode = .never
        field.returnKeyType = .search
        field.autocorrectionType = .no
        field.autocapitalizationType = .words
        field.delegate = context.coordinator
        field.addTarget(
            context.coordinator,
            action: #selector(Coordinator.editingChanged(_:)),
            for: .editingChanged
        )
        handle.field = field
        field.accessibilityIdentifier = "search.field"
        context.coordinator.onChange = onChange
        context.coordinator.onEditingChanged = onEditingChanged
        context.coordinator.onSubmit = onSubmit
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        handle.field = uiView
        uiView.isEnabled = isEnabled
        uiView.placeholder = NSLocalizedString(placeholder.key, comment: "")
        context.coordinator.onChange = onChange
        context.coordinator.onEditingChanged = onEditingChanged
        context.coordinator.onSubmit = onSubmit

        // Writing while a composition is in flight resets the marked text and drops
        // the candidate the user just picked.
        guard uiView.markedTextRange == nil, uiView.text != text else { return }
        uiView.text = text
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: UITextField,
        context: Context
    ) -> CGSize? {
        let height = uiView.sizeThatFits(
            CGSize(width: proposal.width ?? .infinity, height: .infinity)
        ).height
        return CGSize(width: proposal.width ?? 0, height: max(height, 22))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(handle: handle)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        private let handle: MapSearchFieldHandle
        var onChange: (String) -> Void = { _ in }
        var onEditingChanged: (Bool) -> Void = { _ in }
        var onSubmit: () -> Void = {}

        init(handle: MapSearchFieldHandle) {
            self.handle = handle
        }

        @objc func editingChanged(_ field: UITextField) {
            guard let committed = MapSearchQuery.committed(
                handle.currentText,
                marked: field.markedTextRange != nil
            ) else {
                return
            }
            onChange(committed)
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            onEditingChanged(true)
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            onEditingChanged(false)
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            onSubmit()
            return false
        }
    }
}
