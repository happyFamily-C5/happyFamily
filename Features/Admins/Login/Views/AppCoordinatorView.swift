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
                        onRegisterTapped: { model.handleRegister() },
                        onAppleRegisterTapped: { model.handleRegister() },
                        onLoginTapped: { model.goToLogin() }
                    )
                case .roleSelection:
                    RoleSelectionView(
                        onContinueTapped: { role in Task { await model.completeOnboarding(role, router: router) } },
                        onBackTapped: { model.goToRegister() }
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
                        userLocation: model.donorProfile?.recommendationLocationLabel ?? "Lokasi Anda",
                        userCoordinate: model.donorLocationCoordinate,
                        onSaveLocation: { label, coordinate in
                            try await model.saveDonorLocation(label: label, coordinate: coordinate)
                        }
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
