import SwiftUI

/// Hosts the root auth/app coordinator. `AppRouter` arrives from the
/// WindowGroup environment (`Main.swift`) and flows down to every screen.
struct ContentView: View {
    var body: some View {
        AppCoordinatorView()
    }
}

#Preview {
    ContentView()
        .environment(AppRouter())
}
