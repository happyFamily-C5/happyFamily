import SwiftUI

struct LoginAnimatedGreenGradientBackground: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Color("5-LightSoftCyan")
            
            LinearGradient(
                colors: [
                    Color("5-LightSoftCyan"),
                    Color("4-MediumSoftCyan"),
                    Color("3-DarkSoftCyan").opacity(0.55)
                ],
                startPoint: isAnimating ? .topTrailing : .topLeading,
                endPoint: isAnimating ? .bottomLeading : .bottomTrailing
            )
            .scaleEffect(1.18)
            .rotationEffect(.degrees(isAnimating ? 4 : -4))
            .opacity(0.88)
            
            LinearGradient(
                colors: [
                    Color.white.opacity(0.36),
                    Color.clear,
                    Color("4-MediumSoftCyan").opacity(0.35)
                ],
                startPoint: isAnimating ? .bottomLeading : .topTrailing,
                endPoint: isAnimating ? .topTrailing : .bottomLeading
            )
            .scaleEffect(1.25)
            .rotationEffect(.degrees(isAnimating ? -5 : 5))
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 8.5).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

#Preview {
    LoginAnimatedGreenGradientBackground()
}
