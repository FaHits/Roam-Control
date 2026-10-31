import Foundation
import SwiftUI
import UIKit

struct RouteLibraryView: View {
    let isRouteActive: Bool
    let isPaired: Bool
    let onRun: (RouteRunConfiguration) -> Void
    let onClose: () -> Void
    let onEditActiveRoute: () -> Void

    @State private var model: RouteLibraryModel
    @State private var isPresentingEditor = false
    @State private var routeForSetup: RouteDefinition?
    @State private var routePendingDeletion: RouteDefinition?
    @State private var routePendingRename: RouteDefinition?

    init(
        isRouteActive: Bool,
        isPaired: Bool,
        onRun: @escaping (RouteRunConfiguration) -> Void,
        onClose: @escaping () -> Void,
        onEditActiveRoute: @escaping () -> Void
    ) {
        self.isRouteActive = isRouteActive
        self.isPaired = isPaired
        self.onRun = onRun
        self.onClose = onClose
        self.onEditActiveRoute = onEditActiveRoute
        _model = State(initialValue: RouteLibraryModel())
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isRouteActive {
                    activeRunBanner
                }

                if let message = model.errorMessage {
                    errorBanner(message)
                        .padding(.horizontal, 18)
                        .padding(.top, 12)
                }

                routeList
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Routes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onClose)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("New Route", systemImage: "plus") {
                        isPresentingEditor = true
                    }
                }
            }
        }
        .sheet(isPresented: $isPresentingEditor) {
            editorSheet
        }
        .sheet(item: $routeForSetup) { route in
            RouteRunSetupView(
                route: route,
                isPaired: isPaired,
                onRun: { configuration in
                    routeForSetup = nil
                    onRun(configuration)
                },
                onCancel: {
                    routeForSetup = nil
                }
            )
        }
        .confirmationDialog(
            "Delete route?",
            isPresented: deletionConfirmationBinding,
            titleVisibility: .visible
        ) {
            Button("Delete Route", role: .destructive) {
                deletePendingRoute()
            }
            Button("Cancel", role: .cancel) {
                routePendingDeletion = nil
            }
        } message: {
            Text("This route will be permanently removed.")
        }
        .sheet(item: $routePendingRename) { route in
            RouteRenameSheet(
                initialName: route.name,
                onCancel: {
                    routePendingRename = nil
                },
                onRename: { name in
                    rename(route, to: name)
                }
            )
        }
    }

    private var routeList: some View {
        List {
            if model.routes.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: RouteSymbol.library)
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("Draw a route to start a repeatable run.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(model.routes) { route in
                    Button {
                        routeForSetup = route
                    } label: {
                        routeRow(route)
                    }
                    .buttonStyle(.plain)
                    .disabled(isRouteActive)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if !isRouteActive {
                            Button("Delete") {
                                routePendingDeletion = route
                            }
                            .tint(.red)
                            Button("Rename") {
                                beginRename(route)
                            }
                            .tint(.blue)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private func routeRow(_ route: RouteDefinition) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(route.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Text(distanceText(for: route))
                    Text(route.isClosed ? "Closed" : "Open")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Text("Updated \(route.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Image(systemName: isRouteActive ? "lock.fill" : "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var activeRunBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(
                "Stop the active run before changing this route.",
                systemImage: "stop.circle.fill"
            )
            .font(.subheadline)
            .fixedSize(horizontal: false, vertical: true)

            Button("View active run", action: onEditActiveRoute)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 18)
        .padding(.top, 12)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            Button("Dismiss") {
                model.clearError()
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var editorSheet: some View {
        RouteEditorView(
            existingRoute: nil,
            onSave: { route in
                model.upsert(route)
                if model.errorMessage == nil {
                    isPresentingEditor = false
                }
            },
            onCancel: {
                isPresentingEditor = false
            }
        )
        .safeAreaInset(edge: .top, spacing: 0) {
            if let message = model.errorMessage {
                errorBanner(message)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(.bar)
            }
        }
    }

    private var deletionConfirmationBinding: Binding<Bool> {
        Binding(
            get: { routePendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    routePendingDeletion = nil
                }
            }
        )
    }

    private func distanceText(for route: RouteDefinition) -> String {
        guard let meters = try? RouteGeometry(
            points: route.points,
            isClosed: route.isClosed
        ).totalDistance else {
            return "—"
        }

        if meters < 1000 {
            return String(format: "%.0f m", meters)
        }
        return String(format: "%.1f km", meters / 1000)
    }

    private func beginRename(_ route: RouteDefinition) {
        routePendingRename = route
    }

    private func rename(_ route: RouteDefinition, to rawName: String) {
        guard !isRouteActive,
              let name = RouteNameValidator.normalizedName(from: rawName) else {
            return
        }
        var updatedRoute = route
        updatedRoute.name = name
        updatedRoute.updatedAt = .now
        model.upsert(updatedRoute)
        routePendingRename = nil
    }

    private func deletePendingRoute() {
        guard !isRouteActive, let route = routePendingDeletion else {
            return
        }
        model.delete(id: route.id)
        routePendingDeletion = nil
    }
}

private struct RouteRenameSheet: View {
    let initialName: String
    let onCancel: () -> Void
    let onRename: (String) -> Void

    @State private var fieldHandle = RouteRenameTextFieldHandle()
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Enter a new name for this route.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    RouteRenameTextField(initialText: initialName, handle: fieldHandle)
                        .frame(minHeight: 44)

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Rename Route")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Rename") {
                        guard let name = RouteNameValidator.normalizedName(
                            from: fieldHandle.currentText
                        ) else {
                            errorMessage = String(localized: "Route name cannot be empty.")
                            return
                        }
                        onRename(name)
                    }
                    .accessibilityIdentifier("routeRenameConfirm")
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private final class RouteRenameTextFieldHandle {
    weak var textField: UITextField?

    /// `text(in:)` includes marked text that the SwiftUI binding never receives.
    var currentText: String {
        guard let textField else {
            return ""
        }
        guard let range = textField.textRange(
            from: textField.beginningOfDocument,
            to: textField.endOfDocument
        ) else {
            return textField.text ?? ""
        }
        return textField.text(in: range) ?? textField.text ?? ""
    }
}

private struct RouteRenameTextField: UIViewRepresentable {
    let initialText: String
    let handle: RouteRenameTextFieldHandle

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.text = initialText
        textField.font = .preferredFont(forTextStyle: .body)
        textField.adjustsFontForContentSizeCategory = true
        textField.borderStyle = .roundedRect
        textField.clearButtonMode = .whileEditing
        textField.returnKeyType = .done
        textField.delegate = context.coordinator
        textField.accessibilityIdentifier = "routeRenameField"
        handle.textField = textField

        DispatchQueue.main.async {
            textField.becomeFirstResponder()
        }
        return textField
    }

    func updateUIView(_ textField: UITextField, context: Context) {
        handle.textField = textField
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }
    }
}
