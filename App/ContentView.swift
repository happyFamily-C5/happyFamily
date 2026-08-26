import SwiftUI

struct ContentView: View {
    var body: some View {
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
