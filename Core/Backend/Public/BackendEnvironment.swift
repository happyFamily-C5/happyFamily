import Foundation

enum BackendDeploymentEnvironment: String, Codable, Sendable {
    case local
    case staging
    case production
}

struct BackendEnvironment: Sendable, Equatable {
    let baseURL: URL
    let publishableKey: String
    let deployment: BackendDeploymentEnvironment

    var functionsURL: URL {
        baseURL.appending(path: "functions/v1", directoryHint: .isDirectory)
    }

    static func load(bundle: Bundle = .main) throws -> BackendEnvironment {
        try load(values: bundle.infoDictionary ?? [:])
    }

    static func load(values: [String: Any]) throws -> BackendEnvironment {
        guard
            let rawURL = values["KumpulBackendURL"] as? String,
            let baseURL = URL(string: rawURL),
            let scheme = baseURL.scheme,
            scheme == "https" || (scheme == "http" && baseURL.host == "127.0.0.1")
        else {
            throw BackendError.configuration("KumpulBackendURL")
        }
        guard
            let publishableKey = values["KumpulBackendPublishableKey"] as? String,
            !publishableKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw BackendError.configuration("KumpulBackendPublishableKey")
        }
        guard
            let rawDeployment = values["KumpulBackendEnvironment"] as? String,
            let deployment = BackendDeploymentEnvironment(rawValue: rawDeployment)
        else {
            throw BackendError.configuration("KumpulBackendEnvironment")
        }
        return BackendEnvironment(
            baseURL: baseURL,
            publishableKey: publishableKey,
            deployment: deployment
        )
    }
}
