import SwiftUI

struct ProfileTopBar: View {
    var onCloseTapped: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onCloseTapped) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 36, height: 36)
                    .background(Color(.systemGray6))
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

struct ProfileBackBar: View {
    var showsSave: Bool = false
    var onBackTapped: () -> Void
    var onSaveTapped: () -> Void = {}
    
    var body: some View {
        HStack {
            Button(action: onBackTapped) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 36, height: 36)
                    .background(Color(.systemGray6))
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            if showsSave {
                Button(action: onSaveTapped) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 36, height: 36)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

struct ProfileMenuRow: View {
    let title: String
    var onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ProfileSectionTitle: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(.primary)
    }
}

struct ProfileTextInput: View {
    let placeholder: String
    @Binding var text: String
    var minHeight: CGFloat = 48
    var isMultiline = false
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        Group {
            if isMultiline {
                TextEditor(text: $text)
                    .font(.system(size: 14, weight: .medium))
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(minHeight: minHeight)
                    .overlay(alignment: .topLeading) {
                        if text.isEmpty {
                            Text(placeholder)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(.placeholderText))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 16)
                                .allowsHitTesting(false)
                        }
                    }
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(keyboardType == .emailAddress ? .never : .words)
                    .autocorrectionDisabled()
                    .font(.system(size: 14, weight: .medium))
                    .padding(.horizontal, 16)
                    .frame(height: minHeight)
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(18)
    }
}
