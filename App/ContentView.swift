import SwiftUI

/// The main app is the organiser-facing side of .kumpul.
struct ContentView: View {
    @Environment(AppRouter.self) var router
    @State private var donationVM = DonationViewModel()
    @State private var eventStore = AdminEventStore()
    
    var body: some View {
        @Bindable var router = router
    
        NavigationStack(path: $router.adminPath){
            DashboardView()
                .adminsRouter(router)
        }
        .environment(router)
        .environment(eventStore)
//        
//        NavigationStack(path: $router.donersPath){
//            HomeView(
//                title: "Ecoday | Drop Your Unused Shirt",
//                manager: "EcoTouch Indonesia",
//                capacity: 250,
//                maxCapacity: 500
//            )
//                .donersRouter(router)
//        }
//        .environment(router)
//        .environment(donationVM)
    }
}

#Preview {
    ContentView()
        .environment(AppRouter())
}
