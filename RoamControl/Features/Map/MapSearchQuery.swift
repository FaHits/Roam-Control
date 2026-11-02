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
}
