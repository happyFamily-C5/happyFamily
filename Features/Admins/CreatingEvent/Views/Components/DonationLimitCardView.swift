import SwiftUI

@MainActor
struct DonationLimitCardView: View {
    @Binding var selectedLimit: Int // kg per donor
    @State private var isPickerOpen: Bool = false

    private let limitOptions = [1, 2, 5, 10]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Limit Donasi per Donatur")
                .font(.body).bold()
                .foregroundColor(.primary)
                .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 0) {
                // Baris Utama (Trigger)
                Button(action: {
                    withAnimation(.snappy) {
                        isPickerOpen.toggle()
                    }
                }) {
                    HStack {
                        Text("Jumlah")
                            .font(.body)
                            .foregroundColor(.primary)

                        Spacer()

                        HStack(spacing: 8) {
                            Text("\(selectedLimit) kg")
                                .font(.body)

                            Image(systemName: "chevron.up.chevron.down")
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 2)
                    }
                    .padding(16)
                }
                .buttonStyle(PlainButtonStyle())

                if isPickerOpen {
                    Divider()
                        .padding(.horizontal, 16)

                    Picker("Limit", selection: $selectedLimit) {
                        ForEach(limitOptions, id: \.self) { amount in
                            Text("\(amount) kg").tag(amount)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .background(Color(.systemGray6))
            .cornerRadius(30)
        }
    }
}

// MARK: - Preview

#Preview(traits: .sizeThatFitsLayout) {
    @Previewable @State var limit = 1

    return DonationLimitCardView(selectedLimit: $limit)
        .padding()
}
