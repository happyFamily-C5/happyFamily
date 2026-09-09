import SwiftUI

struct EditEventHeaderView: View {
    var onBackTapped: () -> Void
    var onSaveTapped: () -> Void
    var showsSaveButton: Bool = true
    
    var body: some View {
        HStack {
            Button(action: onBackTapped) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 36, height: 36)
                    .background(Color(.systemGray6))
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            Text("Edit Acara")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.primary)
            
            Spacer()
            
            if showsSaveButton {
                Button(action: onSaveTapped) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 36, height: 36)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityIdentifier("editEventSave")
            } else {
                Color.clear
                    .frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    EditEventHeaderView(
        onBackTapped: { print("Back") },
        onSaveTapped: { print("Save") }
    )
    .padding(.vertical)
}
