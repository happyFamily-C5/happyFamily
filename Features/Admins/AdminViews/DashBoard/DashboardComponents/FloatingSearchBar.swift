import SwiftUI

struct FloatingSearchBar: View {
    @Binding var searchText: String
    /// Owned by the parent so tapping anywhere outside can clear focus.
    @FocusState.Binding var isSearchFocused: Bool
    var onMicTapped: () -> Void
    var onQrTapped: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Kotak Search + Ikon Kaca Pembesar & Mic
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search", text: $searchText)
                    .font(.system(size: 15))
                    .focused($isSearchFocused)
                    .submitLabel(.search)
                
                Button(action: onMicTapped) {
                    Image(systemName: "mic.fill")
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 30))
            
          
            Button(action: onQrTapped) {
                Image(systemName: "qrcode")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(width: 48, height: 48)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 24))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
           
            Color(.systemBackground).opacity(0.8)
        )
    }
}

// MARK: - Preview
#Preview(traits: .sizeThatFitsLayout) {
    @Previewable @State var text: String = ""
    @Previewable @FocusState var focused: Bool

    FloatingSearchBar(
        searchText: $text,
        isSearchFocused: $focused,
        onMicTapped: { print("Mic diklik!") },
        onQrTapped: { print("QR diklik!") }
    )
    .padding()
}
