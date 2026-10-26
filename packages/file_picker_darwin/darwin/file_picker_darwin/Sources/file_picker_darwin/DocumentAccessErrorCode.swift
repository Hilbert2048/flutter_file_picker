import Foundation
import FileProvider

/// Pure error policy shared by picker/access code and the native regression test.
enum DocumentAccessErrorCode {
    static func classify(_ error: Error) -> String {
        var current = error as NSError
        // Providers can wrap their own errors in a Cocoa coordination error.
        for _ in 0..<8 {
            switch (current.domain, current.code) {
            case (NSCocoaErrorDomain, NSFileReadNoSuchFileError),
                 (NSCocoaErrorDomain, NSFileNoSuchFileError),
                 (NSPOSIXErrorDomain, 2),
                 (NSFileProviderErrorDomain, NSFileProviderError.Code.noSuchItem.rawValue):
                return "not_found"
            case (NSCocoaErrorDomain, NSFileReadNoPermissionError), (NSPOSIXErrorDomain, 13):
                return "permission_denied"
            case (NSFileProviderErrorDomain, NSFileProviderError.Code.notAuthenticated.rawValue):
                return "authorization_required"
            case (NSURLErrorDomain, _),
                 (NSFileProviderErrorDomain, NSFileProviderError.Code.serverUnreachable.rawValue):
                return "provider_unavailable"
            default:
                guard let underlying = current.userInfo[NSUnderlyingErrorKey] as? NSError else {
                    return "document_access_failed"
                }
                current = underlying
            }
        }
        return "document_access_failed"
    }
}
