import SwiftUI

/// The main app is the organiser-facing side of .kumpul.
struct ContentView: View {
    @Environment(AppRouter.self) var router
    
    @State private var eventStore = AdminEventStore()
    
    var body: some View {
        @Bindable var router = router
    
        NavigationStack(path: $router.path){
            DashboardView()
                .adminsRouter(router)
        }
        .environment(router)
        .environment(eventStore)
    }
}

#Preview {
    ContentView()
        .environment(AppRouter())
}
