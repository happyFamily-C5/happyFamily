import Foundation
@testable import happyFamily
import Testing

@Suite("Authenticated routing")
struct AuthRoutingTests {
    @Test func adminOnboardingDoesNotRequestSameEmailChange() {
        #expect(!AppCoordinatorView.shouldRequestEmailChange(
            currentWorkspaceEmail: "",
            submittedEmail: "admin@example.invalid"
        ))
    }

    @Test func noServerRoleRequiresRoleSelection() {
        #expect(AuthRouting.destination(for: profile(role: nil)) == .roleSelection)
    }

    @Test func incompleteDonorRequiresProfileCompletion() {
        #expect(AuthRouting.destination(for: profile(role: .donor, name: "", phone: nil)) == .donorProfileCompletion)
    }

    @Test func completeDonorLandsOnDonorHome() {
        #expect(AuthRouting.destination(for: profile(role: .donor, name: "Donor", phone: "+628123456789")) == .donorHome)
    }

    @Test func incompleteAdminRequiresWorkspaceCompletion() {
        #expect(AuthRouting.destination(for: profile(role: .admin), workspaceIsPublishable: false) == .adminWorkspaceCompletion)
    }

    @Test func completeAdminNeverRoutesToDonorHome() {
        #expect(AuthRouting.destination(for: profile(role: .admin), workspaceIsPublishable: true) == .adminDashboard)
    }

    private func profile(role: AccountRoleCode?, name: String = "Admin", phone: String? = "+628123456789") -> AccountProfileData {
        AccountProfileData(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            role: role,
            displayName: name,
            phoneE164: phone,
            address: nil,
            recommendationLocationLabel: nil,
            avatarObjectPath: nil
        )
    }
}
