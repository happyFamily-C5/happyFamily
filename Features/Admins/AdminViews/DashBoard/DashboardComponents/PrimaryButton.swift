import SwiftUI

struct PrimaryButton: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color("3-DarkSoftCyan"))
                .cornerRadius(30)
        }
        .padding(.horizontal, 24)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    VStack(spacing: 20) {
        PrimaryButton(title: "Mulai Membuat Event") {
            print("Tombol diklik!")
        }

        PrimaryButton(title: "Lanjut") {
            print("Tombol lanjut diklik!")
        }
    }
    .padding()
}
