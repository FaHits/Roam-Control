import Foundation

extension String {
    /// Looks up this English source string in the String Catalog at runtime.
    ///
    /// Used for text that a `LocalizedStringKey` cannot reach directly, such as
    /// computed properties and messages produced by service types. The English
    /// source string is kept as the catalog key, so matching logic elsewhere is
    /// unaffected.
    var localized: String { NSLocalizedString(self, comment: "") }
}
