import SwiftUI

struct EditEventDeleteButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Hapus Acara")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(red: 0.78, green: 0.12, blue: 0.12))
                .cornerRadius(26)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
        .background(Color(.systemBackground).opacity(0.96))
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    EditEventDeleteButton {
        print("Delete")
    }
}
