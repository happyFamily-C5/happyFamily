import SwiftUI

struct ContentView: View {
    @State var router = AppRouter()
    var body: some View {
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

#Preview {
    ContentView()
        .environment(AppRouter())
}
