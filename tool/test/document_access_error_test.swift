import Foundation
import FileProvider

@main
struct DocumentAccessErrorTest {
    static func main() {
        let missing = NSError(domain: NSFileProviderErrorDomain,
                              code: NSFileProviderError.Code.noSuchItem.rawValue)
        assert(DocumentAccessErrorCode.classify(missing) == "not_found")
        assert(DocumentAccessErrorCode.classify(NSError(
            domain: NSCocoaErrorDomain, code: NSFileReadUnknownError,
            userInfo: [NSUnderlyingErrorKey: missing])) == "not_found")
        assert(DocumentAccessErrorCode.classify(NSError(
            domain: NSFileProviderErrorDomain,
            code: NSFileProviderError.Code.notAuthenticated.rawValue)) == "authorization_required")
        assert(DocumentAccessErrorCode.classify(NSError(
            domain: NSFileProviderErrorDomain,
            code: NSFileProviderError.Code.serverUnreachable.rawValue)) == "provider_unavailable")
        assert(DocumentAccessErrorCode.classify(NSError(
            domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError)) == "permission_denied")
        assert(DocumentAccessErrorCode.classify(NSError(
            domain: "unrecognized", code: 1)) == "document_access_failed")
        print("6 document access classifications passed")
    }
}
