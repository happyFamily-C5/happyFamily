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
    var isSaveDisabled = false
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
                .disabled(isSaveDisabled)
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
