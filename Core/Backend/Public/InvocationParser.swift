import Foundation

struct EventInvocation: Equatable, Sendable {
    let token: String
}

enum InvocationParser {
    static func parse(_ url: URL) throws -> EventInvocation {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw BackendError.invalidInvocationURL
        }
        let acceptedNames = ["event", "invocation", "token"]
        let token = components.queryItems?
            .first(where: { acceptedNames.contains($0.name.lowercased()) })?
            .value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let token, (32 ... 200).contains(token.count) else {
            throw BackendError.invalidInvocationURL
        }
        return EventInvocation(token: token)
    }
}
