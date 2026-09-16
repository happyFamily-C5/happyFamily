import SwiftUI

/// The root owns navigation rendering only. Every session, onboarding, and
/// account decision lives in `AppCoordinatorViewModel`; role and completion
/// status come from the hosted account contract.
struct AppCoordinatorView: View {
    @Environment(AppRouter.self) private var router
    @State private var model = AppCoordinatorViewModel()

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.donersPath) {
            Group {
                switch model.currentScreen {
                case .splash:
                    LoginSplashView {
                        model.splashAnimationCompleted()
                    }
                    .task { await model.bootstrapSession(isSplash: true, router: router) }
                case .login:
                    LoginWelcomeView(
                        onAuthenticated: { Task { await model.bootstrapSession(router: router) } },
                        onRegisterTapped: { model.goToRegister() }
                    )
                case .register:
                    RegisterAccountView(
                        onRegisterTapped: { draft in model.handleRegister(draft) },
                        onAppleRegisterTapped: { draft in model.handleRegister(draft) },
                        onLoginTapped: { model.goToLogin() }
                    )
                case .roleSelection:
                    RoleSelectionView(
                        onContinueTapped: { role in Task { await model.completeOnboarding(role, router: router) } },
                        onBackTapped: { model.goToRegister() }
                    )
                case .donorProfileCompletion:
                    if let donorProfile = model.donorProfile {
                        DonorProfileCompletionView(profile: donorProfile) { update in
                            try await model.completeDonorProfile(update)
                        }
                    }
                case .organizationInfo:
                    RegisterOrganizationInfoView(
                        initialEmail: model.registeredAccount?.email ?? model.adminProfile.email,
                        onCreateAccountTapped: { profile in
                            Task { await model.completeAdminWorkspace(profile) }
                        },
                        onBackTapped: { model.goToRoleSelection() }
                    )
                case .adminDashboard:
                    DashboardView(
                        initialProfile: model.adminProfile,
                        onLogout: { model.logout(router: router) },
                        onDeleteAccount: { try await model.deleteAccount(router: router) },
                        onSaveProfile: { profile in try await model.saveAdminProfile(profile) }
                    )
                case .donorHome:
                    MainTabView(
                        router: router,
                        userLocation: model.donorProfile?.recommendationLocationLabel ?? "Lokasi Anda"
                    )
                }
            }
            .donersRouter(router)
            .alert("Tidak dapat melanjutkan", isPresented: Binding(
                get: { model.isShowingError },
                set: {
                    if !$0 {
                        model.dismissError()
                    }
                }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(model.bootstrapError ?? "Terjadi kesalahan yang tidak diketahui.")
            }
        }
    }
}

#Preview {
    AppCoordinatorView().environment(AppRouter())
}
