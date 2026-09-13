import SwiftUI

struct LoginAuthPrimaryButton: View {
    let title: String
    var isDisabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button {
            guard !isDisabled else { return }
            action()
        } label: {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    isDisabled ? AppColor.primaryCyan : Color(
                        "2-BoldDarkSoftCyan"
                    )
                )
                .cornerRadius(30)
                .shadow(color: Color.black.opacity(isDisabled ? 0 : 0.12), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.9 : 1)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    LoginAuthPrimaryButton(title: "Masuk") {}
        .padding()
}
