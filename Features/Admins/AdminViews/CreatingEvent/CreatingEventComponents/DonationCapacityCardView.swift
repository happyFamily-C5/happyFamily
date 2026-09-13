import SwiftUI

@MainActor
struct DonationCapacityCardView: View {
    @Binding var selectedCapacity: Int // kg (10, 20, ..., 100, 200, 300, 400, 500)
    @State private var isPickerOpen: Bool = false

    private let capacityOptions = Array(stride(from: 10, through: 100, by: 10)) + [200, 300, 400, 500]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Kapasitas Donasi")
                .font(.system(size: 14, weight: .semibold))
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
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.primary)

                        Spacer()

                        HStack(spacing: 4) {
                            Text("\(selectedCapacity) kg")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.secondary)

                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 2)
                    }
                    .padding(16)
                }
                .buttonStyle(PlainButtonStyle())

                // Wheel Picker: 10-100 kg, lalu 200-500 kg
                if isPickerOpen {
                    Divider()
                        .padding(.horizontal, 16)

                    Picker("Kapasitas", selection: $selectedCapacity) {
                        ForEach(capacityOptions, id: \.self) { amount in
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
    @Previewable @State var capacity = 50

    return DonationCapacityCardView(selectedCapacity: $capacity)
        .padding()
}
