import Foundation

enum AuthDestination: Sendable, Equatable {
    case signIn
    case roleSelection
    case donorProfileCompletion
    case adminWorkspaceCompletion
    case donorHome
    case adminDashboard
}

enum AuthRouting {
    static func destination(
        for profile: AccountProfileData,
        workspaceIsPublishable: Bool? = nil
    ) -> AuthDestination {
        guard let role = profile.role else { return .roleSelection }
        switch role {
        case .donor:
            return profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || profile.phoneE164?.isEmpty != false
                ? .donorProfileCompletion
                : .donorHome
        case .admin:
            return workspaceIsPublishable == true ? .adminDashboard : .adminWorkspaceCompletion
        }
    }
}
