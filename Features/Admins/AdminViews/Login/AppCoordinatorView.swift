import SwiftUI

// Enum untuk merepresentasikan setiap halaman dalam alur Auth & App
enum AppScreen {
    case splash
    case login
    case register
    case roleSelection
    case organizationInfo
    case dashboard // atau EventDetailView / Home
}

struct AppCoordinatorView: View {
    @State private var currentScreen: AppScreen = .splash
    @State private var selectedRole: String = "Pengelola"
    @State private var registeredAccount: RegisterAccountDraft?
    @State private var adminProfile: AdminProfile = .defaultProfile
    
    var body: some View {
        NavigationStack {
            Group {
                switch currentScreen {
                case .splash:
                    LoginSplashView {
                        currentScreen = .login
                    }
                    
                case .login:
                    LoginWelcomeView(
                        onLoginTapped: {
                            currentScreen = .dashboard
                        },
                        onAppleLoginTapped: {
                            currentScreen = .dashboard
                        },
                        onRegisterTapped: {
                            currentScreen = .register
                        }
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
                        onLoginTapped: {
                            currentScreen = .login
                        }
                    )
                    
                case .roleSelection:
                    // 4. Layar Role Selection (Sesuai Screenshot Kanan)
                    RoleSelectionView(
                        onContinueTapped: { role in
                            selectedRole = role
                            
                            if role == "Pengelola" {
                                currentScreen = .organizationInfo
                            } else {
                                currentScreen = .dashboard
                            }
                        },
                        onBackTapped: {
                            currentScreen = .register
                        }
                    )
                    
                case .organizationInfo:
                    RegisterOrganizationInfoView(
                        initialEmail: registeredAccount?.email ?? "",
                        onCreateAccountTapped: { profile in
                            adminProfile = profile
                            currentScreen = .dashboard
                        },
                        onBackTapped: {
                            currentScreen = .roleSelection
                        }
                    )
                    
                case .dashboard:
                    // 5. Masuk ke halaman utama aplikasi / Event Detail / Dashboard
                    DashboardView(
                        initialProfile: adminProfile,
                        onLogout: {
                            currentScreen = .login
                        }
                    )
                }
            }
        }
    }
}

#Preview {
    AppCoordinatorView()
}
