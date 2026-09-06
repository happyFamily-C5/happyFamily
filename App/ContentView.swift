import SwiftUI

/// The main app is the organiser-facing side of .kumpul: the donor flow
/// (Home, Donation form, scan, label) now lives entirely in the App Clip.
struct ContentView: View {
    
    @Environment(AppRouter.self) var router
    
    var body: some View {
        AppCoordinatorView()
            .environment(router)
    }
}

#Preview {
    ContentView()
        .environment(AppRouter())
}
