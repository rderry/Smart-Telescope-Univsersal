import Foundation

enum AppIssueFormatter {
    static func storageWarning(for error: Error) -> String {
        if isSandboxPermissionError(error) {
            return "Persistent storage is unavailable under the current app sandbox permissions. The app is using temporary in-memory data."
        }

        return "Persistent storage is unavailable right now. The app is using temporary in-memory data."
    }

    static func persistenceMessage(for action: String, error: Error) -> String {
        if isSandboxPermissionError(error) {
            return "Couldn't \(action) because sandboxed storage access was denied."
        }

        return "Couldn't \(action): \(error.localizedDescription)"
    }

    static func remoteServiceWarning(service: String, error: Error) -> String {
        if isNetworkPermissionError(error) {
            return "\(service) is unavailable because outbound network access is blocked by the app sandbox."
        }

        return "\(service) is unavailable right now. The app will keep using its local bundled data."
    }

    static func remoteServiceMessage(service: String, error: Error) -> String {
        if isNetworkPermissionError(error) {
            return "\(service) is unavailable because outbound network access is blocked by the app sandbox."
        }

        return "\(service) is unavailable right now: \(error.localizedDescription)"
    }

    private static func isSandboxPermissionError(_ error: Error) -> Bool {
        let nsError = error as NSError

        if nsError.domain == NSCocoaErrorDomain,
           nsError.code == NSFileReadNoPermissionError || nsError.code == NSFileWriteNoPermissionError {
            return true
        }

        if nsError.domain == NSPOSIXErrorDomain,
           nsError.code == EACCES || nsError.code == EPERM {
            return true
        }

        return nsError.localizedDescription.localizedCaseInsensitiveContains("permission")
            || nsError.localizedDescription.localizedCaseInsensitiveContains("operation not permitted")
            || nsError.localizedDescription.localizedCaseInsensitiveContains("sandbox")
    }

    private static func isNetworkPermissionError(_ error: Error) -> Bool {
        let nsError = error as NSError

        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorDataNotAllowed {
            return true
        }

        return isSandboxPermissionError(error)
    }
}
