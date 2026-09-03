import SwiftUI

/// The main app is the organiser-facing side of .kumpul: unauthenticated
/// users land on the login screen; authenticated ones get the dashboard.
/// The donor flow (Home, Donation form, scan, label) lives in the App Clip.
struct ContentView: View {
    private enum AccessState {
        case checking
        case needsLogin
        case authenticated
    }

    @State private var accessState: AccessState = .checking
    @State private var authSession: (any AuthSession)? = BackendDependencies.authSessionOrDefault()
    @State private var invocation = FullAppInvocationModel()

    var body: some View {
        switch accessState {
        case .checking:
            ProgressView("Memuat…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task { await restoreSession() }
        case .needsLogin:
            LoginView { accessState = .authenticated }
        case .authenticated:
            dashboard
        }
    }

    private var dashboard: some View {
        DashboardView()
            .overlay {
                if invocation.isLoading {
                    ProgressView("Memuat acara…")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                }
            }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                guard let url = activity.webpageURL else { return }
                Task { await invocation.handle(url) }
            }
            .sheet(item: Binding(
                get: { invocation.event },
                set: {
                    if $0 == nil {
                        invocation.dismiss()
                    }
                }
            )) { event in
                FullAppInvocationView(event: event)
            }
            .alert(
                "Tautan acara tidak dapat dibuka",
                isPresented: Binding(
                    get: { invocation.errorMessage != nil },
                    set: {
                        if !$0 {
                            invocation.errorMessage = nil
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(invocation.errorMessage ?? "Terjadi kesalahan.")
            }
    }

    private func restoreSession() async {
        guard let authSession else {
            accessState = .needsLogin
            return
        }
        do {
            _ = try await authSession.current()
            accessState = .authenticated
        } catch {
            accessState = .needsLogin
        }
    }
}

private struct FullAppInvocationView: View {
    let event: PublicEventDTO

    var body: some View {
        NavigationStack {
            List {
                Section("Acara .kumpul") {
                    LabeledContent("Nama", value: event.name)
                    LabeledContent("Lokasi", value: event.locationName)
                    LabeledContent("Alamat", value: event.locationAddress)
                    LabeledContent(
                        "Kapasitas",
                        value: "\(event.receivedWeightGrams / 1000) / \(event.capacityGrams / 1000) kg"
                    )
                }
                Section {
                    Text(
                        event.availability.acceptsBookings
                            ? "Tautan donasi valid. Gunakan alur donor .kumpul pada perangkat ini."
                            : "Acara ini sudah tidak menerima booking baru."
                    )
                }
            }
            .navigationTitle("Detail Acara")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ContentView()
}
