import SwiftUI

struct CancelEventStatusIcon: View {
    var size: CGFloat = 72
    
    var body: some View {
        Image(systemName: "trash")
            .font(.system(size: size, weight: .regular))
            .foregroundColor(Color(red: 0.78, green: 0.12, blue: 0.12))
            .accessibilityHidden(true)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    CancelEventStatusIcon()
        .padding()
}
