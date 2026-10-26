import Foundation
#if os(iOS)
import Flutter
#elseif os(macOS)
import FlutterMacOS
#endif

/// Owns only security scopes. Never copies, moves or deletes selected files.
final class DocumentReferenceStore {
    private let work = DispatchQueue(label: "file_picker.document_reference_access")
    private var leases: [String: (URL, Bool)] = [:]

    deinit {
        for (url, scoped) in leases.values where scoped {
            url.stopAccessingSecurityScopedResource()
        }
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) -> Bool {
        switch call.method {
        case "referenceAcquire":
            guard let args = call.arguments as? [String: Any],
                  let data = args["bookmark"] as? FlutterStandardTypedData else {
                result(FlutterError(code: "invalid_arguments", message: "Missing bookmark", details: nil))
                return true
            }
            work.async {
                do {
                    var stale = false
                    #if os(macOS)
                    let options: URL.BookmarkResolutionOptions = [.withSecurityScope, .withoutUI]
                    #else
                    let options: URL.BookmarkResolutionOptions = [.withoutUI]
                    #endif
                    let url = try URL(resolvingBookmarkData: data.data, options: options,
                                      relativeTo: nil, bookmarkDataIsStale: &stale)
                    let scoped = url.startAccessingSecurityScopedResource()
                    do {
                        let info = try self.describe(url)
                        let id = UUID().uuidString
                        self.leases[id] = (url, scoped)
                        let response = info.merging(["leaseId": id]) { _, new in new }
                        DispatchQueue.main.async { result(response) }
                    } catch {
                        if scoped { url.stopAccessingSecurityScopedResource() }
                        throw error
                    }
                } catch { DispatchQueue.main.async { result(Self.failure(error)) } }
            }
            return true
        case "referenceRelease":
            let id = (call.arguments as? [String: Any])?["leaseId"] as? String
            work.async {
                if let id, let (url, scoped) = self.leases.removeValue(forKey: id), scoped {
                    url.stopAccessingSecurityScopedResource()
                }
                DispatchQueue.main.async { result(nil) }
            }
            return true
        default: return false
        }
    }

    func selected(_ urls: [URL]) throws -> [[String: Any]] {
        try urls.map { url in
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            return try describe(url)
        }
    }

    private func describe(_ url: URL) throws -> [String: Any] {
        // Metadata/bookmark access is coordinated; the caller must also
        // coordinate subsequent content reads rather than reading this URL
        // after its lease has ended.
        var coordinationError: NSError?
        var response: Result<[String: Any], Error>?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { readable in
            response = Result {
                let values = try readable.resourceValues(forKeys: [
                    .isDirectoryKey, .fileResourceIdentifierKey, .volumeIdentifierKey
                ])
                #if os(macOS)
                let options: URL.BookmarkCreationOptions = [.withSecurityScope, .securityScopeAllowOnlyReadAccess]
                #else
                let options: URL.BookmarkCreationOptions = [.minimalBookmark]
                #endif
                let bookmark = try readable.bookmarkData(options: options,
                    includingResourceValuesForKeys: nil, relativeTo: nil)
                let identity: String
                if let file = values.fileResourceIdentifier as? NSData,
                   let volume = values.volumeIdentifier {
                    identity = "\(volume)/\(file.base64EncodedString())"
                } else {
                    identity = readable.standardizedFileURL.resolvingSymlinksInPath().absoluteString
                }
                return ["bookmark": FlutterStandardTypedData(bytes: bookmark),
                        "uri": readable.absoluteString, "name": readable.lastPathComponent,
                        "isDirectory": values.isDirectory ?? false, "identity": identity]
            }
        }
        if let error = coordinationError { throw error }
        guard let response else { throw CocoaError(.fileReadUnknown) }
        return try response.get()
    }

    static func failure(_ error: Error) -> FlutterError {
        let ns = error as NSError
        let code = DocumentAccessErrorCode.classify(error)
        // Do not return bookmarks or private document paths in diagnostics.
        return FlutterError(code: code, message: "Document access failed",
                            details: ["domain": ns.domain, "nativeCode": ns.code])
    }
}
