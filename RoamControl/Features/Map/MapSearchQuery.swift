import Foundation

enum MapSearchQuery {
    /// Normalizes a typed query for an overseas search.
    ///
    /// Disabled keeps the query byte-for-byte: the caller already trims it and
    /// the domestic search path must stay identical to 0.10.0.
    static func normalized(_ raw: String, overseas: Bool) -> String {
        guard overseas else { return raw }

        let segments = raw
            .split(whereSeparator: { character in
                character == ","
                    || character == "，"
                    || character == "、"
                    || character == ";"
                    || character == "；"
                    || character.isNewline
            })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return segments.last ?? ""
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
