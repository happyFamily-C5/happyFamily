import SwiftUI

@main
struct Main: App {
    var body: some Scene {
        WindowGroup {
//            ContentView()
            HomeView(
                title: "Ecoday | Drop Your Unused Shirt",
                manager: "EcoTouch Indonesia",
                capacity: 250,
                maxCapacity: 500
            )
        }
    }
}
