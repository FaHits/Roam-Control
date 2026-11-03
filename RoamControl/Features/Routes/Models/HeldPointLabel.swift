import Foundation

/// Naming rules for a held point. The resolved place name wins; a blank result falls back to the
/// caller's fixed label so the card never shows a route name or an empty title.
enum HeldPointLabel {
    static func title(resolvedName: String?, fallback: String = "Held here") -> String {
        guard
            let name = resolvedName?.trimmingCharacters(in: .whitespacesAndNewlines),
            !name.isEmpty
        else {
            return fallback
        }
        return name
    }
}
