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

/// A compact centred dialog over the current screen. A sheet gave this one field a whole panel;
/// an overlay keeps it the size of what it asks.
struct RenameDialog: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let initialName: String
    let onCancel: () -> Void
    let onSubmit: (String) -> Void

    @State private var model: RenameSheetModel
    @State private var fieldHandle = RenameFieldHandle()

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
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)

            VStack(spacing: 12) {
                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                RenameField(initialText: initialName, handle: fieldHandle) {
                    model.text = fieldHandle.currentText
                }
                .padding(.horizontal, 10)
                .frame(height: 34)
                .background(
                    .secondary.opacity(0.25),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )

                HStack(spacing: 8) {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .frame(maxWidth: .infinity, minHeight: 34)
                            .background(
                                .secondary.opacity(0.18),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        guard let name = model.submit() else { return }
                        onSubmit(name)
                    } label: {
                        Text("Save")
                            .frame(maxWidth: .infinity, minHeight: 34)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!model.canSubmit)
                }
            }
            .padding(16)
            .frame(width: 270)
            .background(
                .regularMaterial,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("rename.dialog")
        }
    }
}

final class RenameFieldHandle {
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

struct RenameField: UIViewRepresentable {
    let initialText: String
    let handle: RenameFieldHandle
    let onChange: () -> Void

    func makeUIView(context: Context) -> UITextField {
        let textField: UITextField = .init()
        textField.text = initialText
        textField.font = .preferredFont(forTextStyle: .subheadline)
        textField.adjustsFontForContentSizeCategory = true
        textField.borderStyle = .none
        textField.backgroundColor = .clear
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

    /// Same rule as the search field: report a real text height, capped so no parent can stretch
    /// the field into a panel.
    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: UITextField,
        context: Context
    ) -> CGSize? {
        let height = uiView.sizeThatFits(
            CGSize(width: proposal.width ?? .infinity, height: .infinity)
        ).height
        return CGSize(width: proposal.width ?? 0, height: min(max(height, 22), 34))
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
