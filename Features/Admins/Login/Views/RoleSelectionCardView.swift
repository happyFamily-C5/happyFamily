import SwiftUI

struct RoleSelectionView: View {
    @State private var selectedRole: Role = .pengelola
    var onContinueTapped: (String) -> Void
    var onBackTapped: () -> Void

    enum Role: String {
        case pengelola = "Pengelola"
        case donatur = "Donatur"
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 32) {
                Text("Jenis pengguna yang mana anda ?")
                    .font(.largeTitle).bold()
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppColor.primaryCyan)
            }

            HStack(spacing: 16) {
                RoleCard(
                    title: "Pengelola",
                    imageName: "pengelola",
                    backgroundColor: Color(red: 0.9320, green: 0.8958, blue: 0.9627),
                    isSelected: selectedRole == .pengelola
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedRole = .pengelola
                    }
                }

                Spacer()

                RoleCard(
                    title: "Donatur",
                    imageName: "donatur",
                    backgroundColor: Color(red: 0.7529, green: 0.9216, blue: 0.8941),
                    isSelected: selectedRole == .donatur
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedRole = .donatur
                    }
                }
            }
            .padding(.top, 12)

            Text("Untuk memberikan pengalaman yang sesuai, kami perlu mengetahui peran Anda.")
                .font(.callout)
                .multilineTextAlignment(.center)
            Spacer()
            PrimaryButton(title: "Lanjut") {
                onContinueTapped(selectedRole.rawValue)
            }
        }

        .padding(.horizontal, 20)
        .navigationBarHidden(true)
    }
}

private struct RoleCard: View {
    let title: String
    let imageName: String
    let backgroundColor: Color
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.title3).bold()
                        .foregroundColor(isSelected ? AppColor.primaryCyan : .primary)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(AppColor.primaryCyan)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(backgroundColor)
                        .frame(width: 145, height: 234)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(
                                    isSelected ? AppColor.primaryCyan : Color.clear,
                                    lineWidth: 3
                                )
                        )

                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: title == "Pengelola" ? 157 : 145)
                        .offset(x: title == "Pengelola" ? 20 : -20)
                }
                .frame(width: 145, height: 234, alignment: .bottom)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

#Preview {
    NavigationStack {
        RoleSelectionView(
            onContinueTapped: { role in print("Lanjut diklik dengan peran \(role)") },
            onBackTapped: { print("Kembali diklik") }
        )
    }
}
