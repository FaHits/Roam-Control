import Foundation

enum RouteStoreError: Error, Equatable {
    case unsupportedSchema(Int)
    case corruptedFile
    case writeFailed
}

/// On-disk shape of the route library. Private on purpose: callers hand routes in and get routes
/// back, and never see the envelope or its version.
private struct RouteLibraryDocument: Codable {
    let schemaVersion: Int
    let routes: [RouteDefinition]
}

/// Atomic JSON store for the route library at `Application Support/RoamControl/routes.json`.
///
/// Reading never writes. A missing file is an empty library, so the first run creates nothing;
/// an undecodable file is reported as `.corruptedFile` and left byte for byte as it was; a file
/// from a newer schema is refused with its own version number so the UI can name it.
struct RouteStore: Sendable {
    static let currentSchemaVersion = 1

    static var liveFileURL: URL {
        let supportDirectory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first
            ?? URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)
        return supportDirectory
            .appendingPathComponent("RoamControl", isDirectory: true)
            .appendingPathComponent("routes.json", isDirectory: false)
    }

    let fileURL: URL

    init(fileURL: URL = RouteStore.liveFileURL) {
        self.fileURL = fileURL
    }

    /// Returns the stored routes, or an empty array when the file does not exist yet.
    ///
    /// Decoding failures are the file's fault, so they surface as `.corruptedFile`; a read error
    /// such as a permission problem keeps its original error instead of claiming corruption.
    func load() throws -> [RouteDefinition] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        let document: RouteLibraryDocument
        do {
            document = try Self.makeDecoder().decode(RouteLibraryDocument.self, from: data)
        } catch {
            throw RouteStoreError.corruptedFile
        }

        guard document.schemaVersion <= Self.currentSchemaVersion else {
            throw RouteStoreError.unsupportedSchema(document.schemaVersion)
        }
        return document.routes
    }

    /// Replaces the whole library atomically, creating `RoamControl` on the first save.
    ///
    /// Encoding runs before anything touches the disk, so a failed encode leaves the previous
    /// file untouched instead of truncating it.
    func save(_ routes: [RouteDefinition]) throws {
        let document = RouteLibraryDocument(
            schemaVersion: Self.currentSchemaVersion,
            routes: routes
        )

        let data: Data
        do {
            data = try Self.makeEncoder().encode(document)
        } catch {
            throw RouteStoreError.writeFailed
        }

        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        } catch {
            throw RouteStoreError.writeFailed
        }

        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw RouteStoreError.writeFailed
        }
    }

    /// ISO-8601 loses sub-second precision: dates come back truncated to whole seconds.
    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
