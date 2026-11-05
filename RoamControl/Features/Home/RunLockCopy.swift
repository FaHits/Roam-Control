import Foundation

/// The wording that explains why a control is unavailable while a run owns the
/// route. Kept in one place so the list footer and the search placeholder never
/// drift apart.
enum RunLockCopy {
    static let defaultSearchPlaceholder = LocalizedStringResource("Search places or coordinates")
    static let lockedListFooter = LocalizedStringResource(
        "Finish or hold the run before changing saved places."
    )
    static let lockedSearchPlaceholder = LocalizedStringResource(
        "Finish or hold the run to search places"
    )

    static func listFooter(isLocked: Bool) -> LocalizedStringResource? {
        isLocked ? lockedListFooter : nil
    }

    static func searchPlaceholder(isLocked: Bool) -> LocalizedStringResource {
        isLocked ? lockedSearchPlaceholder : defaultSearchPlaceholder
    }
}
