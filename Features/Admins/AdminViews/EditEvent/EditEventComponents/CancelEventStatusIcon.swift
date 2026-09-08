import SwiftUI

struct CancelEventStatusIcon: View {
    var body: some View {
        Image("xmark")
            .resizable()
            .scaledToFit()
            .frame(width: 123)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    CancelEventStatusIcon()
        .padding()
}
