import SwiftUI

/// A regular application host for previewing App Clip views with Xcode's JIT executor.
@main
struct HappyFamilyPreviewHostApp: App {
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(router)
        }
    }
}
