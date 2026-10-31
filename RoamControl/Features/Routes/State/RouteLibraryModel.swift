import Foundation
import Observation

/// In-memory view of the route library.
///
/// `routes` is the single source of truth for the UI and is always ordered by `updatedAt`,
/// newest first. A save or delete builds the whole next array, writes it first and only then
/// replaces `routes`, so a failed write cannot leave the list half updated. A failed load keeps
/// whatever the list already holds and only reports the error; it never writes an empty library
/// over data the model could not read.
@MainActor
@Observable
final class RouteLibraryModel {
    private(set) var routes: [RouteDefinition]
    private(set) var isLoading: Bool
    private(set) var errorMessage: String?

    @ObservationIgnored private let store: RouteStore

    init(store: RouteStore = RouteStore()) {
        self.store = store
        self.routes = []
        self.isLoading = false
        load()
    }

    func load() {
        isLoading = true
        defer { isLoading = false }

        do {
            routes = sorted(try store.load())
            errorMessage = nil
        } catch {
            errorMessage = Self.loadErrorMessage(for: error)
        }
    }

    /// Trims the name, then replaces the route with the same id or appends it. Callers own
    /// `id`, `createdAt` and `updatedAt`; the model never rewrites them.
    func upsert(_ route: RouteDefinition) {
        guard let name = RouteNameValidator.normalizedName(from: route.name) else {
            errorMessage = Self.emptyNameMessage
            return
        }

        var candidate = route
        candidate.name = name

        var next = routes
        if let index = next.firstIndex(where: { $0.id == candidate.id }) {
            next[index] = candidate
        } else {
            next.append(candidate)
        }
        commit(next)
    }

    /// Deletes the matching route only; an unknown id is a no-op that never touches the store.
    func delete(id: UUID) {
        guard routes.contains(where: { $0.id == id }) else {
            return
        }
        commit(routes.filter { $0.id != id })
    }

    func route(id: UUID) -> RouteDefinition? {
        routes.first { $0.id == id }
    }

    func clearError() {
        errorMessage = nil
    }

    // MARK: - Persistence

    private func commit(_ candidate: [RouteDefinition]) {
        do {
            try store.save(candidate)
        } catch {
            errorMessage = Self.saveFailureMessage
            return
        }
        routes = sorted(candidate)
        errorMessage = nil
    }

    private func sorted(_ routes: [RouteDefinition]) -> [RouteDefinition] {
        routes.sorted { lhs, rhs in
            if lhs.updatedAt != rhs.updatedAt {
                return lhs.updatedAt > rhs.updatedAt
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    // MARK: - Messages

    private static var emptyNameMessage: String { String(localized: "Route name cannot be empty.") }
    private static var saveFailureMessage: String { String(localized: "Could not save routes.") }

    private static func loadErrorMessage(for error: Error) -> String {
        guard let storeError = error as? RouteStoreError else {
            return String(localized: "Could not load routes.")
        }
        switch storeError {
        case .corruptedFile:
            return String(localized: "Routes file is corrupted.")
        case .unsupportedSchema(let version):
            return String(format: String(localized: "Routes file uses unsupported schema version %lld."), version)
        case .writeFailed:
            return String(localized: "Could not load routes.")
        }
    }
}
