import SwiftUI
import PhotosUI

@MainActor
struct ImagePickerCardView: View {
    let selectedImage: Image?
    @Binding var selectedItem: PhotosPickerItem?
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
                
//                Button(action: onDeleteTapped) {
//                    Image(systemName: "xmark")
//                        .font(.system(size: 12, weight: .bold))
//                        .foregroundColor(.white)
//                        .frame(width: 28, height: 28)
//                        .background(Color.black.opacity(0.6))
//                        .clipShape(Circle())
//                }
//                .padding(12)
            } else {
                // MARK: - Empty State
                
                RoundedRectangle(cornerRadius: 32)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppColor.accentCyan,
                                AppColor.primaryCyan
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(maxWidth: .infinity)
                    .frame(width: 362, height: 216)
                    .overlay(
                        ZStack(alignment: .trailing) {
                            HStack(alignment: .center,spacing: 16) {
                                VStack(alignment: .leading){
                                    Text("Ajak lebih \nbanyak orang \ndengan sampul \nyang menarik")
                                        .font(.title3)
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.leading)
                                        .padding(.top, 12)
                                    Spacer()
                                    PhotosPicker(selection: $selectedItem, matching: .images) {
                                        Text("Tambah sampul")
                                            .foregroundStyle(.black).bold()
                                            .padding(.vertical, 12)
                                            .padding(.horizontal, 22)
                                            .background(
                                                Color.white,
                                                in: RoundedRectangle(cornerRadius: 32)
                                            )
                                    }
                                }
                                .padding(20)
                                
                                Spacer()
                                
                            }
                            Image("addImageCard")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 170)
                        }
                    )
            }
        }
        .padding(.horizontal, 16)
    }
}

#Preview {
    ImagePickerCardView(selectedImage: .none, selectedItem: .constant(nil), onDeleteTapped: {})
}
