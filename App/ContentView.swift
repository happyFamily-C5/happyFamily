import SwiftUI

/// The main app is the organiser-facing side of .kumpul: the donor flow
/// (Home, Donation form, scan, label) now lives entirely in the App Clip.
struct ContentView: View {
    var body: some View {
        DashboardView()
    }
}

#Preview {
    ContentView()
}
