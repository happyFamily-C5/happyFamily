import SwiftUI

@main
struct Main: App {
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            ContentView()
//            MainTabView(router: router)
                .environment(router)
        }
    }
}
