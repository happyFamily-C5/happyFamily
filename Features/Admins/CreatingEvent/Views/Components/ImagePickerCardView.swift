import SwiftUI

@MainActor
struct ImagePickerCardView: View {
    let selectedImage: Image?
    var onAddTapped: () -> Void
    var onDeleteTapped: () -> Void

    var body: some View {
        ZStack {
            if let image = selectedImage {
                // MARK: - Ready / Filled State

                image
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                // MARK: - Empty State

                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .overlay(
                        HStack(spacing: 16) {
                            Text("Ajak lebih banyak orang dengan sampul yang menarik")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)

                            Spacer()

                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemBackground))
                                    .frame(width: 80, height: 64)
                                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)

                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 24))
                                    .foregroundColor(Color("3-DarkSoftCyan"))
                            }
                        }
                        .padding(.horizontal, 20)
                    )
                    .overlay(
                        HStack {
                            Text("Tambah sampul")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color(.systemBackground))
                                .cornerRadius(8)
                                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                            Spacer()
                        }
                        .padding(16),
                        alignment: .bottomLeading
                    )
            }
        }
        .padding(.horizontal, 16)
    }
}
