import SwiftUI

@main
struct Main: App {
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(router)
        }
    }
}
