import SwiftUI

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
            .font(.title2).bold()
            .foregroundColor(.primary)
    }
}

struct ProfileTextInput: View {
    let placeholder: String
    @Binding var text: String
    var minHeight: CGFloat = 52
    var isMultiline = false
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        Group {
            if isMultiline {
                TextEditor(text: $text)
                    .font(.body).bold()
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .frame(minHeight: minHeight)
                    .overlay(alignment: .topLeading) {
                        if text.isEmpty {
                            Text(placeholder)
                                .font(.body)
                                .foregroundColor(Color(.placeholderText))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 13)
                                .allowsHitTesting(false)
                        }
                    }
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(keyboardType == .emailAddress ? .never : .words)
                    .autocorrectionDisabled()
                    .font(.body)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .frame(height: minHeight)
            }
        }
        .background(AppColor.fieldBackground)
        .cornerRadius(24)
    }
}
