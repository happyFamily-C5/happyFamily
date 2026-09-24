import CoreLocation
import Foundation
import Observation
import SwiftUI

enum AppScreen {
    case splash, login, register, roleSelection, adminDashboard, donorHome
}

/// View model behind `AppCoordinatorView`. It owns every authentication,
/// onboarding, and account-state decision; the coordinator view only renders
/// `currentScreen` and forwards UI callbacks. Role and completion status come
/// from the hosted account contract; no local registration field grants
/// access.
@MainActor
@Observable
final class AppCoordinatorViewModel {
    private(set) var currentScreen: AppScreen = .splash
    private(set) var donorProfile: AccountProfileData?
    var adminProfile: AdminProfile = .defaultProfile
    private(set) var isSplashAnimationDone = false
    private(set) var isSessionResolved = false
    private(set) var bootstrapError: String?

    var isShowingError: Bool {
        bootstrapError != nil
    }

    var donorLocationCoordinate: CLLocationCoordinate2D? {
        guard let latitude = donorProfile?.recommendationLatitude,
              let longitude = donorProfile?.recommendationLongitude
        else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func splashAnimationCompleted() {
        isSplashAnimationDone = true
        advanceAfterSplash()
    }

    func advanceAfterSplash() {
        guard isSplashAnimationDone, isSessionResolved else { return }
        withAnimation(.easeInOut(duration: 0.35)) {
            if currentScreen == .splash {
                currentScreen = .login
            }
        }
    }

    func bootstrapSession(isSplash: Bool = false, router: AppRouter) async {
        defer {
            if isSplash {
                isSessionResolved = true
                advanceAfterSplash()
            }
        }
        guard let authSession = BackendDependencies.authSessionOrDefault() else { return }
        do {
            _ = try await authSession.current()
            let account = try BackendDependencies.accountClient()
            let profile = try await account.myProfile()
            donorProfile = profile
            if profile.role == .admin {
                let workspace = try await BackendDependencies.organizerClient().workspaceProfile()
                // Logo display is cosmetic: a failed fetch leaves the image
                // nil while the server path is still tracked.
                var logoData: Data?
                if let logoPath = workspace.logoObjectPath, !logoPath.isEmpty {
                    logoData = await BackendDependencies.storageMediaClientOrDefault()?
                        .fetchPublicObject(bucket: "workspace-logos", path: logoPath)
                }
                adminProfile = AdminProfile(
                    companyName: workspace.name,
                    companyAddress: workspace.officeAddress ?? "",
                    phoneNumber: workspace.officePhoneE164 ?? "",
                    email: workspace.officeEmail ?? "",
                    imageData: logoData,
                    logoObjectPath: workspace.logoObjectPath
                )
            }
            route(AuthRouting.destination(for: profile), router: router)
        } catch {
            // No stored/valid session is normal at splash. Authenticated
            // bootstrap errors must stay visible, never default to Admin.
            if !isSplash {
                bootstrapError = error.localizedDescription
            }
        }
    }

    func handleRegister() {
        currentScreen = .roleSelection
    }

    func goToLogin() {
        currentScreen = .login
    }

    func goToRegister() {
        currentScreen = .register
    }

    func goToRoleSelection() {
        currentScreen = .roleSelection
    }

    func completeOnboarding(_ roleTitle: String, router: AppRouter) async {
        let role: AccountRoleCode = roleTitle == "Donatur" ? .donor : .admin
        do {
            let account = try BackendDependencies.accountClient()
            _ = try await account.completeOnboarding(role: role)
            await bootstrapSession(router: router)
        } catch {
            bootstrapError = error.localizedDescription
        }
    }

    func saveAdminProfile(_ profile: AdminProfile) async throws {
        let account = try BackendDependencies.accountClient()
        // The workspace row owns the current logo path; the server reads
        // "" as "remove logo", so an existing logo is always re-sent by path
        // (or replaced by a freshly uploaded path) and never blanked.
        let workspace = try await BackendDependencies.organizerClient().workspaceProfile()
        var logoObjectPath = workspace.logoObjectPath ?? ""
        if let imageData = profile.imageData,
           adminProfile.logoObjectPath == nil || adminProfile.imageData != imageData
        {
            logoObjectPath = try await BackendDependencies.storageMediaClient()
                .uploadWorkspaceLogo(data: imageData, workspaceId: workspace.id)
        }
        try await account.updateWorkspace(AccountWorkspaceUpdate(
            name: profile.companyName, address: profile.companyAddress,
            phoneE164: profile.phoneNumber, email: profile.email,
            logoObjectPath: logoObjectPath
        ))
        if Self.shouldRequestEmailChange(
            currentWorkspaceEmail: adminProfile.email,
            submittedEmail: profile.email
        ) {
            _ = try await account.requestEmailChange(email: profile.email)
        }
        adminProfile = profile
        adminProfile.logoObjectPath = logoObjectPath
    }

    func saveDonorProfile(_ profile: DonorProfile, router: AppRouter) async throws {
        let account = try BackendDependencies.accountClient()
        let savedLocation = donorProfile
        let saved = try await account.updateProfile(AccountProfileUpdate(
            displayName: profile.fullName,
            phoneE164: profile.phoneE164,
            address: profile.address,
            locationLabel: savedLocation?.recommendationLocationLabel ?? "",
            latitude: savedLocation?.recommendationLatitude,
            longitude: savedLocation?.recommendationLongitude,
            avatarObjectPath: profile.avatarObjectPath
        ))
        donorProfile = saved
        router.donorProfile = DonorProfile(
            fullName: saved.displayName,
            address: saved.address ?? "",
            imageData: profile.imageData,
            id: saved.id,
            phoneE164: saved.phoneE164 ?? "",
            avatarObjectPath: saved.avatarObjectPath ?? ""
        )
    }

    func saveDonorLocation(label: String, coordinate: CLLocationCoordinate2D) async throws {
        guard let currentProfile = donorProfile else {
            throw BackendError.configuration("profil donor belum tersedia")
        }

        let saved = try await BackendDependencies.accountClient().updateProfile(AccountProfileUpdate(
            displayName: currentProfile.displayName,
            phoneE164: currentProfile.phoneE164 ?? "",
            address: currentProfile.address ?? "",
            locationLabel: label,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            avatarObjectPath: currentProfile.avatarObjectPath ?? ""
        ))
        donorProfile = saved
    }

    nonisolated static func shouldRequestEmailChange(
        currentWorkspaceEmail: String,
        submittedEmail: String
    ) -> Bool {
        let current = currentWorkspaceEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let submitted = submittedEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        return !current.isEmpty && current.caseInsensitiveCompare(submitted) != .orderedSame
    }

    private func route(_ destination: AuthDestination, router: AppRouter) {
        switch destination {
        case .signIn: currentScreen = .login
        case .roleSelection: currentScreen = .roleSelection
        case .donorHome:
            syncDonorRouterProfile(router: router)
            currentScreen = .donorHome
        case .adminDashboard:
            syncAdminRouterProfile(router: router)
            currentScreen = .adminDashboard
        }
    }

    /// The donor profile screen reads the router profile so its edits stay
    /// backend-backed. Avatar display is cosmetic: a failed fetch leaves the
    /// image nil while the server path is still tracked.
    private func syncDonorRouterProfile(router: AppRouter) {
        guard let account = donorProfile else { return }
        router.onLogout = { self.logout(router: router) }
        router.onDeleteAccount = { try await self.deleteAccount(router: router) }
        router.onSaveDonorProfile = { profile in
            try await self.saveDonorProfile(profile, router: router)
        }

        let keepsCachedAvatar = router.donorProfile.id == account.id
            && router.donorProfile.avatarObjectPath == (account.avatarObjectPath ?? "")
        var profile = DonorProfile(
            fullName: account.displayName,
            address: account.address ?? "",
            imageData: keepsCachedAvatar ? router.donorProfile.imageData : nil,
            id: account.id,
            phoneE164: account.phoneE164 ?? "",
            avatarObjectPath: account.avatarObjectPath ?? ""
        )
        router.donorProfile = profile
        if profile.imageData == nil,
           let avatarPath = account.avatarObjectPath,
           !avatarPath.isEmpty
        {
            Task {
                let avatarData = await BackendDependencies.storageMediaClientOrDefault()?
                    .fetchPublicObject(bucket: "profile-avatars", path: avatarPath)
                if let avatarData,
                   router.donorProfile.id == account.id,
                   router.donorProfile.avatarObjectPath == avatarPath
                {
                    profile.imageData = avatarData
                    router.donorProfile = profile
                }
            }
        }
    }

    /// Keeps the admin profile route in sync with the coordinator state so
    /// the same backend-backed edits are shown after relaunch.
    private func syncAdminRouterProfile(router: AppRouter) {
        router.onLogout = { self.logout(router: router) }
        router.onDeleteAccount = { try await self.deleteAccount(router: router) }
        router.onSaveAdminProfile = { profile in
            try await self.saveAdminProfile(profile)
            router.adminProfile = self.adminProfile
        }
        router.adminProfile = adminProfile
    }

    func logout(router: AppRouter) {
        Task {
            do {
                try await BackendDependencies.logoutService().logout()
                router.popToRoot()
                currentScreen = .login
            } catch {
                bootstrapError = "Keluar gagal. Sesi Anda tetap aktif: \(error.localizedDescription)"
            }
        }
    }

    func deleteAccount(router: AppRouter) async throws {
        try await BackendDependencies.accountClient().deleteAccount()
        await BackendDependencies.clearDeletedAccountState()
        router.popToRoot()
        donorProfile = nil
        adminProfile = .defaultProfile
        currentScreen = .login
    }

    func dismissError() {
        bootstrapError = nil
    }
}
