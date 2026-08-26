import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            OpenCamera()
        }
        ZStack {
            AppColor.baseColor
                .ignoresSafeArea()

            Text("Hello, World!")
                .font(.title)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
}
