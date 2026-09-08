import SwiftUI

/// The main app is the organiser-facing side of .kumpul.
struct ContentView: View {
    @Environment(AppRouter.self) var router
    @State private var donationVM = DonationViewModel()
    @State private var eventStore = AdminEventStore()
    
    var body: some View {
        @Bindable var router = router
    
//        NavigationStack(path: $router.adminPath){
//            DashboardView()
//                .adminsRouter(router)
//        }
//        .environment(router)
//        .environment(eventStore)
//        
        NavigationStack(path: $router.donersPath){
//            HomeView(
//                userLocation: "Jakarta Pusat",
//                title: "Ecoday | Drop Your Unused Shirt",
//                manager: "EcoTouch Indonesia",
//                capacity: 250,
//                maxCapacity: 500
//            )
            
            SelectedEventDetailView(
                title: "Ecoday Shirt | drop your unused shirt",
                name: "EcoTouch Indonesia",
                date: "9 Sept - 16 Sept 2026",
                time: "Hari Kerja · 09.00 - 16.00"
            )
                .donersRouter(router)
        }
        .environment(router)
        .environment(donationVM)
    }
}

#Preview {
    ContentView()
        .environment(AppRouter())
}
