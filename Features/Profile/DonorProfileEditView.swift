import SwiftUI
import PhotosUI

@MainActor
struct DonorProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    
    @Binding var fullName: String
    @Binding var address: String
    @Binding var selectedImageData: Data?
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var draftFullName: String
    @State private var draftAddress: String
    @State private var draftImageData: Data?
    @State private var isPhotoPickerPresented = false
    @FocusState private var isFieldFocused: Bool
    
    init(
        fullName: Binding<String>,
        address: Binding<String>,
        selectedImageData: Binding<Data?>
    ) {
        _fullName = fullName
        _address = address
        _selectedImageData = selectedImageData
        _draftFullName = State(initialValue: fullName.wrappedValue)
        _draftAddress = State(initialValue: address.wrappedValue)
        _draftImageData = State(initialValue: selectedImageData.wrappedValue)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProfileBackBar(
                showsSave: true,
                onBackTapped: { dismiss() },
                onSaveTapped: saveProfile
            )
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    Button {
                        isPhotoPickerPresented = true
                    } label: {
                        ZStack(alignment: .bottomTrailing) {
                            ProfileLogoImage(imageData: draftImageData, size: 88)
                            
                            Image(systemName: "photo")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary)
                                .frame(width: 32, height: 32)
                                .background(Color(.systemGray6))
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.08), radius: 5, x: 0, y: 2)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(maxWidth: .infinity)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        ProfileSectionTitle(title: "Informasi Umum")
                        
                        ProfileTextInput(
                            placeholder: "Nama",
                            text: $draftFullName
                        )
                        .focused($isFieldFocused)
                        
                        ProfileTextInput(
                            placeholder: "Alamat",
                            text: $draftAddress,
                            minHeight: 112,
                            isMultiline: true
                        )
                        .focused($isFieldFocused)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color(.systemBackground))
        .navigationBarHidden(true)
        .contentShape(Rectangle())
        .onTapGesture {
            isFieldFocused = false
        }
        .photosPicker(
            isPresented: $isPhotoPickerPresented,
            selection: $selectedItem,
            matching: .images
        )
        .onChange(of: selectedItem, loadSelectedImage)
    }
    
    private func saveProfile() {
        fullName = draftFullName
        address = draftAddress
        selectedImageData = draftImageData
        dismiss()
    }
    
    private func loadSelectedImage(_ oldItem: PhotosPickerItem?, _ newItem: PhotosPickerItem?) {
        Task {
            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                await MainActor.run {
                    draftImageData = data
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var name = "Yuan Dimianta"
    @Previewable @State var address = "Jl. Kutilang 9-2, Palmerah, Kec. Palmerah, Kota Jakarta Barat."
    @Previewable @State var imageData: Data?
    
    DonorProfileEditView(
        fullName: $name,
        address: $address,
        selectedImageData: $imageData
    )
}
