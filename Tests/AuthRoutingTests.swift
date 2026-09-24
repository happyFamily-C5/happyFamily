import Foundation
@testable import happyFamily
import Testing

@Suite("Authenticated routing")
struct AuthRoutingTests {
    @Test func adminOnboardingDoesNotRequestSameEmailChange() {
        #expect(!AppCoordinatorViewModel.shouldRequestEmailChange(
            currentWorkspaceEmail: "",
            submittedEmail: "admin@example.invalid"
        ))
    }

    @Test func noServerRoleRequiresRoleSelection() {
        #expect(AuthRouting.destination(for: profile(role: nil)) == .roleSelection)
    }

    @Test func incompleteDonorLandsOnDonorHome() {
        #expect(AuthRouting.destination(for: profile(role: .donor, name: "", phone: nil)) == .donorHome)
    }

    @Test func completeDonorLandsOnDonorHome() {
        #expect(AuthRouting.destination(for: profile(role: .donor, name: "Donor", phone: "+628123456789")) == .donorHome)
    }

    @Test func incompleteAdminLandsOnDashboard() {
        #expect(AuthRouting.destination(for: profile(role: .admin)) == .adminDashboard)
    }

    @Test func completeAdminNeverRoutesToDonorHome() {
        #expect(AuthRouting.destination(for: profile(role: .admin)) == .adminDashboard)
    }

    private func profile(role: AccountRoleCode?, name: String = "Admin", phone: String? = "+628123456789") -> AccountProfileData {
        AccountProfileData(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            role: role,
            displayName: name,
            phoneE164: phone,
            address: nil,
            recommendationLocationLabel: nil,
            recommendationLatitude: nil,
            recommendationLongitude: nil,
            avatarObjectPath: nil
        )
    }
}

@Suite("Profile completion policy")
struct ProfileCompletionPolicyTests {
    @Test func donorNeedsNameAndPhone() {
        var profile = DonorProfile(fullName: "  ", address: "", imageData: nil, phoneE164: "+628123456789")
        #expect(!ProfileCompletionPolicy.canDonate(profile))

        profile.fullName = "Dina"
        #expect(ProfileCompletionPolicy.canDonate(profile))

        profile.phoneE164 = "  "
        #expect(!ProfileCompletionPolicy.canDonate(profile))
    }

    @Test func adminNeedsAllWorkspaceFields() {
        var profile = AdminProfile(
            companyName: "EcoTouch",
            companyAddress: "Jakarta",
            phoneNumber: "+628123456789",
            email: "team@example.invalid",
            imageData: nil
        )
        #expect(ProfileCompletionPolicy.canCreateEvent(profile))

        profile.companyAddress = "  "
        #expect(!ProfileCompletionPolicy.canCreateEvent(profile))
    }
}
