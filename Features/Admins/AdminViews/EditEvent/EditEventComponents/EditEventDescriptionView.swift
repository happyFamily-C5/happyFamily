import SwiftUI
import UIKit

struct EditEventDescriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isDescriptionFocused: Bool
    
    @Binding var eventDescription: String
    var onSaveTapped: () -> Void = {}
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            EditEventHeaderView(
                onBackTapped: { dismiss() },
                onSaveTapped: {
                    onSaveTapped()
                    dismiss()
                }
            )
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Edit Deskripsi\nAcara")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 20)
                
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $eventDescription)
                        .focused($isDescriptionFocused)
                        .font(.system(size: 13))
                        .lineSpacing(4)
                        .padding(10)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                    
                    if eventDescription.isEmpty {
                        Text("Tuliskan deskripsi acara...")
                            .font(.system(size: 13))
                            .foregroundColor(Color(.placeholderText))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 18)
                            .allowsHitTesting(false)
                    }
                }
                .frame(minHeight: 360, maxHeight: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(18)
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 18)
            .contentShape(Rectangle())
            .onTapGesture {
                isDescriptionFocused = false
                UIApplication.shared.dismissKeyboard()
            }
        }
        .background(Color(.systemBackground))
        .navigationBarHidden(true)
        .scrollDismissesKeyboard(.interactively)
    }
}

private extension UIApplication {
    func dismissKeyboard() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
