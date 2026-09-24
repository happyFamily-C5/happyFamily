import Foundation

enum AuthDestination: Sendable, Equatable {
    case signIn
    case roleSelection
    case donorHome
    case adminDashboard
}

enum AuthRouting {
    static func destination(for profile: AccountProfileData) -> AuthDestination {
        guard let role = profile.role else { return .roleSelection }
        switch role {
        case .donor:
            return .donorHome
        case .admin:
            return .adminDashboard
        }
    }
}
