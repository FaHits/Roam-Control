import SwiftUI
import UIKit

/// Rename rules live here so the sheet stays a thin view and the rules stay testable.
struct RenameSheetModel {
    var text: String

    init(initialName: String) {
        self.text = initialName
    }

    /// Surrounding whitespace and newlines never belong to a submitted name.
    var trimmedName: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Any non-empty name can be submitted, including the name it already has.
    var canSubmit: Bool {
        !trimmedName.isEmpty
    }

    func submit() -> String? {
        canSubmit ? trimmedName : nil
    }
}

struct RenameSheet: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let initialName: String
    let onCancel: () -> Void
    let onSubmit: (String) -> Void

    @State private var model: RenameSheetModel
    @State private var fieldHandle = RenameTextFieldHandle()

    init(
        title: LocalizedStringKey,
        message: LocalizedStringKey,
        initialName: String,
        onCancel: @escaping () -> Void,
        onSubmit: @escaping (String) -> Void
    ) {
        self.title = title
        self.message = message
        self.initialName = initialName
        self.onCancel = onCancel
        self.onSubmit = onSubmit
        _model = State(initialValue: RenameSheetModel(initialName: initialName))
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                RenameTextField(initialText: initialName, handle: fieldHandle) {
                    model.text = fieldHandle.currentText
                }
                .frame(minHeight: 44)

                Spacer(minLength: 0)
            }
            .padding(18)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Rename") {
                        guard let name = model.submit() else {
                            return
                        }
                        onSubmit(name)
                    }
                    .disabled(!model.canSubmit)
                }
            }
        }
        .presentationDetents([.height(300)])
    }
}

final class RenameTextFieldHandle {
    weak var field: UITextField?

    /// `text(in:)` includes marked text that a SwiftUI binding never receives, so a Chinese layout
    /// no longer drops the characters still being composed.
    var currentText: String {
        guard let field,
              let range = field.textRange(from: field.beginningOfDocument, to: field.endOfDocument) else {
            return ""
        }
        return field.text(in: range) ?? ""
    }
}

struct RenameTextField: UIViewRepresentable {
    let initialText: String
    let handle: RenameTextFieldHandle
    let onChange: () -> Void

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.text = initialText
        textField.font = .preferredFont(forTextStyle: .body)
        textField.adjustsFontForContentSizeCategory = true
        textField.borderStyle = .roundedRect
        textField.clearButtonMode = .whileEditing
        textField.returnKeyType = .done
        textField.addTarget(
            context.coordinator,
            action: #selector(Coordinator.editingChanged),
            for: .editingChanged
        )
        textField.addTarget(
            context.coordinator,
            action: #selector(Coordinator.editingEndedOnExit),
            for: .editingDidEndOnExit
        )
        handle.field = textField
        context.coordinator.onChange = onChange

        DispatchQueue.main.async {
            textField.becomeFirstResponder()
        }
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        handle.field = uiView
        context.coordinator.onChange = onChange
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject {
        var onChange: () -> Void = {}

        @objc func editingChanged() {
            onChange()
        }

        @objc func editingEndedOnExit(_ sender: UITextField) {
            sender.resignFirstResponder()
            onChange()
        }
    }
}
