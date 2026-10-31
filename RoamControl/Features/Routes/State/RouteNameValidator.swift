import Foundation

/// Shared route-name rule for the library model and the rename sheet.
enum RouteNameValidator {
    /// Trims surrounding whitespace and newlines, returning `nil` when nothing is left.
    static func normalizedName(from rawName: String) -> String? {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
