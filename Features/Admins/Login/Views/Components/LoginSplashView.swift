import SwiftUI

struct LoginSplashView: View {
    var onAnimationCompleted: () -> Void

    @State private var logoScale: CGFloat = 0.82
    @State private var logoOpacity: Double = 0
    @State private var backgroundOpacity: Double = 0.65

    var body: some View {
        ZStack {
            AppLogoHeaderView(imageSize: 112)
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
                .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: 8)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) {
                logoScale = 1
                logoOpacity = 1
                backgroundOpacity = 1
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                withAnimation(.easeInOut(duration: 0.35)) {
                    onAnimationCompleted()
                }
            }
        }
    }
}

#Preview {
    LoginSplashView {}
}
