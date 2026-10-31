import Foundation
import SwiftUI

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
    @State private var renameText = ""

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
        .alert("Rename Route", isPresented: renameAlertBinding) {
            TextField("Route name", text: $renameText)
            Button("Cancel", role: .cancel) {
                routePendingRename = nil
            }
            Button("Rename") {
                renamePendingRoute()
            }
            .disabled(renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Enter a new name for this route.")
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
                            Button("Delete", role: .destructive) {
                                routePendingDeletion = route
                            }
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

    private var renameAlertBinding: Binding<Bool> {
        Binding(
            get: { routePendingRename != nil },
            set: { isPresented in
                if !isPresented {
                    routePendingRename = nil
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
        renameText = route.name
        routePendingRename = route
    }

    private func renamePendingRoute() {
        guard !isRouteActive, var route = routePendingRename else {
            return
        }
        route.name = renameText
        route.updatedAt = .now
        model.upsert(route)
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
