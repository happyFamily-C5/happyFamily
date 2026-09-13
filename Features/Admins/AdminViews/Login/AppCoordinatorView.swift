import SwiftUI

enum AppScreen {
    case splash, login, register, roleSelection, donorProfileCompletion
    case organizationInfo, adminDashboard, donorHome
}

/// The root owns navigation only. Role and completion status come from the
/// hosted account contract; no local registration field grants access.
struct AppCoordinatorView: View {
    @Environment(AppRouter.self) private var router
    @State private var currentScreen: AppScreen = .splash
    @State private var registeredAccount: RegisterAccountDraft?
    @State private var donorProfile: AccountProfileData?
    @State private var adminProfile: AdminProfile = .defaultProfile
    @State private var isSplashAnimationDone = false
    @State private var isSessionResolved = false
    @State private var bootstrapError: String?

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.donersPath) {
            Group {
                switch currentScreen {
                case .splash:
                    LoginSplashView {
                        isSplashAnimationDone = true
                        advanceAfterSplash()
                    }
                    .task { await bootstrapSession(isSplash: true) }
                case .login:
                    LoginWelcomeView(
                        onAuthenticated: { Task { await bootstrapSession() } },
                        onRegisterTapped: { currentScreen = .register }
                    )
                case .register:
                    RegisterAccountView(
                        onRegisterTapped: { draft in
                            registeredAccount = draft
                            currentScreen = .roleSelection
                        },
                        onAppleRegisterTapped: { draft in
                            registeredAccount = draft
                            currentScreen = .roleSelection
                        },
                        onLoginTapped: { currentScreen = .login }
                    )
                case .roleSelection:
                    RoleSelectionView(
                        onContinueTapped: { role in Task { await completeOnboarding(role) } },
                        onBackTapped: { currentScreen = .register }
                    )
                case .donorProfileCompletion:
                    if let donorProfile {
                        DonorProfileCompletionView(profile: donorProfile) { update in
                            try await completeDonorProfile(update)
                        }
                    }
                case .organizationInfo:
                    RegisterOrganizationInfoView(
                        initialEmail: registeredAccount?.email ?? adminProfile.email,
                        onCreateAccountTapped: { profile in
                            Task { await completeAdminWorkspace(profile) }
                        },
                        onBackTapped: { currentScreen = .roleSelection }
                    )
                case .adminDashboard:
                    DashboardView(
                        initialProfile: adminProfile,
                        onLogout: { logout() },
                        onDeleteAccount: { try await deleteAccount() },
                        onSaveProfile: { profile in try await saveAdminProfile(profile) }
                    )
                case .donorHome:
                    MainTabView(
                        router: router,
                        userLocation: donorProfile?.recommendationLocationLabel ?? "Lokasi Anda"
                    )
                }
            }
            .donersRouter(router)
            .alert("Tidak dapat melanjutkan", isPresented: Binding(
                get: { bootstrapError != nil },
                set: {
                    if !$0 {
                        bootstrapError = nil
                    }
                }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(bootstrapError ?? "Terjadi kesalahan yang tidak diketahui.")
            }
        }
    }

    private func advanceAfterSplash() {
        guard isSplashAnimationDone, isSessionResolved else { return }
        withAnimation(.easeInOut(duration: 0.35)) {
            if currentScreen == .splash {
                currentScreen = .login
            }
        }
    }

    private func bootstrapSession(isSplash: Bool = false) async {
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
            var workspaceIsPublishable: Bool?
            if profile.role == .admin {
                let workspace = try await BackendDependencies.organizerClient().workspaceProfile()
                workspaceIsPublishable = workspace.publishable
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
            route(AuthRouting.destination(for: profile, workspaceIsPublishable: workspaceIsPublishable))
        } catch {
            // No stored/valid session is normal at splash. Authenticated
            // bootstrap errors must stay visible, never default to Admin.
            if !isSplash {
                bootstrapError = error.localizedDescription
            }
        }
    }

    private func completeOnboarding(_ roleTitle: String) async {
        let role: AccountRoleCode = roleTitle == "Donatur" ? .donor : .admin
        do {
            let account = try BackendDependencies.accountClient()
            _ = try await account.completeOnboarding(role: role)
            await bootstrapSession()
        } catch {
            bootstrapError = error.localizedDescription
        }
    }

    private func completeDonorProfile(_ update: AccountProfileUpdate) async throws {
        let account = try BackendDependencies.accountClient()
        donorProfile = try await account.updateProfile(update)
        currentScreen = .donorHome
    }

    private func completeAdminWorkspace(_ profile: AdminProfile) async {
        do {
            // saveAdminProfile refreshes adminProfile with the resolved logo.
            try await saveAdminProfile(profile)
            currentScreen = .adminDashboard
        } catch {
            bootstrapError = error.localizedDescription
        }
    }

    private func saveAdminProfile(_ profile: AdminProfile) async throws {
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

    static func shouldRequestEmailChange(
        currentWorkspaceEmail: String,
        submittedEmail: String
    ) -> Bool {
        let current = currentWorkspaceEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let submitted = submittedEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        return !current.isEmpty && current.caseInsensitiveCompare(submitted) != .orderedSame
    }

    private func route(_ destination: AuthDestination) {
        switch destination {
        case .signIn: currentScreen = .login
        case .roleSelection: currentScreen = .roleSelection
        case .donorProfileCompletion: currentScreen = .donorProfileCompletion
        case .adminWorkspaceCompletion: currentScreen = .organizationInfo
        case .donorHome:
            syncDonorRouterProfile()
            currentScreen = .donorHome
        case .adminDashboard:
            syncAdminRouterProfile()
            currentScreen = .adminDashboard
        }
    }

    /// The donor profile screen reads the router profile so its edits stay
    /// backend-backed. Avatar display is cosmetic: a failed fetch leaves the
    /// image nil while the server path is still tracked.
    private func syncDonorRouterProfile() {
        guard let account = donorProfile else { return }
        router.onLogout = { logout() }
        router.onDeleteAccount = { try await deleteAccount() }
        if router.donorProfile.id != account.id {
            var profile = DonorProfile(
                fullName: account.displayName,
                address: account.address ?? "",
                imageData: nil,
                id: account.id,
                phoneE164: account.phoneE164 ?? "",
                avatarObjectPath: account.avatarObjectPath ?? ""
            )
            if let avatarPath = account.avatarObjectPath, !avatarPath.isEmpty {
                Task {
                    let avatarData = await BackendDependencies.storageMediaClientOrDefault()?
                        .fetchPublicObject(bucket: "profile-avatars", path: avatarPath)
                    if let avatarData {
                        profile.imageData = avatarData
                        router.donorProfile = profile
                    }
                }
            }
            router.donorProfile = profile
        }
    }

    /// Keeps the admin profile route in sync with the coordinator state so
    /// the same backend-backed edits are shown after relaunch.
    private func syncAdminRouterProfile() {
        router.onLogout = { logout() }
        router.onDeleteAccount = { try await deleteAccount() }
        router.onSaveAdminProfile = { profile in
            try await saveAdminProfile(profile)
            router.adminProfile = adminProfile
        }
        router.adminProfile = adminProfile
    }

    private func logout() {
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

    private func deleteAccount() async throws {
        try await BackendDependencies.accountClient().deleteAccount()
        await BackendDependencies.clearDeletedAccountState()
        router.popToRoot()
        registeredAccount = nil
        donorProfile = nil
        adminProfile = .defaultProfile
        currentScreen = .login
    }
}

#Preview {
    AppCoordinatorView().environment(AppRouter())
}
