import Foundation

enum MapSearchQuery {
    /// Splits on the separators a typed place chain uses. Empty segments stay in the
    /// list so a trailing separator is visible to `attempts`.
    private static func segments(_ raw: String) -> [String] {
        raw
            .split(omittingEmptySubsequences: false, whereSeparator: { character in
                character == ","
                    || character == "，"
                    || character == "、"
                    || character == ";"
                    || character == "；"
                    || character.isNewline
            })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    /// Normalizes a typed query for an overseas search.
    ///
    /// Disabled keeps the query byte-for-byte: the caller already trims it and
    /// the domestic search path must stay identical to 0.10.0.
    static func normalized(_ raw: String, overseas: Bool) -> String {
        guard overseas else { return raw }
        return segments(raw).last(where: { !$0.isEmpty }) ?? ""
    }

    /// Queries to try in order. Disabled keeps the single original query.
    ///
    /// A completer session tied to China answers "Tokyo haneda airport" with
    /// nothing, while its trailing segment still resolves. The whole query stays
    /// first so a complete name is never traded for a weaker one.
    static func attempts(_ raw: String, overseas: Bool) -> [String] {
        guard overseas else { return [raw] }
        guard let trailing = segments(raw).last, !trailing.isEmpty, trailing != raw else {
            return [raw]
        }
        return [raw, trailing]
    }

    /// Text a field may write back to its binding.
    ///
    /// While an input method is composing, the visible characters live in marked
    /// text only; writing them back resets the composition and drops the candidate
    /// the user just picked. `nil` tells the caller to skip the write-back.
    static func committed(_ text: String, marked: Bool) -> String? {
        marked ? nil : text
    }
}
