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
                    .disabled(isRouteActive)
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
        .overlay {
            if let route = routePendingRename {
                RenameDialog(
                    title: "Rename Route",
                    message: "Enter a new name for this route.",
                    initialName: route.name,
                    onCancel: {
                        routePendingRename = nil
                    },
                    onSubmit: { name in
                        rename(route, to: name)
                    }
                )
            }
        }
    }

    private var routeList: some View {
        List {
            Section {
                if model.routes.isEmpty {
                    EmptyRouteRow(
                        symbol: RouteSymbol.library,
                        message: "Draw a route to start a repeatable run."
                    )
                } else {
                    ForEach(model.routes) { route in
                        Button {
                            routeForSetup = route
                        } label: {
                            RouteLibraryRow(
                                route: route,
                                distanceText: distanceText(for: route),
                                showsLock: isRouteActive
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("route.row.\(route.name)")
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
            } header: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("My Routes")

                    Spacer(minLength: 8)

                    if !model.routes.isEmpty {
                        Text(model.routes.count.formatted())
                            .foregroundStyle(.secondary)
                    }
                }
                .textCase(nil)
            }
        }
        .listStyle(.insetGrouped)
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

private struct RouteLibraryRow: View {
    let route: RouteDefinition
    let distanceText: String
    let showsLock: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: route.isClosed ? RouteSymbol.library : RouteSymbol.open)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 32, height: 32)
                .background(
                    .blue.opacity(0.15),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(route.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Updated \(route.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Image(systemName: showsLock ? "lock.fill" : "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        let shape = route.isClosed ? String(localized: "Closed") : String(localized: "Open")
        return "\(distanceText) · \(shape)"
    }
}

private struct EmptyRouteRow: View {
    let symbol: String
    let message: LocalizedStringKey

    var body: some View {
        Label(message, systemImage: symbol)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.vertical, 8)
    }
}
