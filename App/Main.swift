import SwiftUI

@main
struct Main: App {
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $router.path) {
                HomeView(
                    title: "Ecoday | Drop Your Unused Shirt",
                    manager: "EcoTouch Indonesia",
                    capacity: 250,
                    maxCapacity: 500
                )
                .donationsRouter()
            }
            .environment(router)
        }
    }
}
