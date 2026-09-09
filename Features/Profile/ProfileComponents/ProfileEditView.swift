import SwiftUI
import PhotosUI

@MainActor
struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    
    @Binding var companyName: String
    @Binding var companyAddress: String
    @Binding var phoneNumber: String
    @Binding var email: String
    @Binding var selectedImageData: Data?
    private let onSave: ((AdminProfile) async throws -> Void)?
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var draftCompanyName: String
    @State private var draftCompanyAddress: String
    @State private var draftPhoneNumber: String
    @State private var draftEmail: String
    @State private var draftImageData: Data?
    @State private var isPhotoPickerPresented = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var isFieldFocused: Bool
    
    init(
        companyName: Binding<String>,
        companyAddress: Binding<String>,
        phoneNumber: Binding<String>,
        email: Binding<String>,
        selectedImageData: Binding<Data?>,
        onSave: ((AdminProfile) async throws -> Void)? = nil
    ) {
        _companyName = companyName
        _companyAddress = companyAddress
        _phoneNumber = phoneNumber
        _email = email
        _selectedImageData = selectedImageData
        _draftCompanyName = State(initialValue: companyName.wrappedValue)
        _draftCompanyAddress = State(initialValue: companyAddress.wrappedValue)
        _draftPhoneNumber = State(initialValue: phoneNumber.wrappedValue)
        _draftEmail = State(initialValue: email.wrappedValue)
        _draftImageData = State(initialValue: selectedImageData.wrappedValue)
        self.onSave = onSave
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProfileBackBar(
                showsSave: true,
                onBackTapped: { dismiss() },
                onSaveTapped: { Task { await saveProfile() } }
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
                            placeholder: "Nama Pengelola",
                            text: $draftCompanyName
                        )
                        .focused($isFieldFocused)
                        
                        ProfileTextInput(
                            placeholder: "Alamat Pengelola",
                            text: $draftCompanyAddress,
                            minHeight: 137,
                            isMultiline: true
                        )
                        .focused($isFieldFocused)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        ProfileSectionTitle(title: "Informasi Kontak")
                        
                        ProfileTextInput(
                            placeholder: "Nomor Telepon",
                            text: $draftPhoneNumber,
                            keyboardType: .phonePad
                        )
                        .focused($isFieldFocused)
                        
                        ProfileTextInput(
                            placeholder: "Email",
                            text: $draftEmail,
                            keyboardType: .emailAddress
                        )
                        .focused($isFieldFocused)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
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
    
    private func saveProfile() async {
        guard !isSaving else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        let updated = AdminProfile(
            companyName: draftCompanyName,
            companyAddress: draftCompanyAddress,
            phoneNumber: draftPhoneNumber,
            email: draftEmail,
            imageData: draftImageData
        )
        do {
            try await onSave?(updated)
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        companyName = draftCompanyName
        companyAddress = draftCompanyAddress
        phoneNumber = draftPhoneNumber
        email = draftEmail
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
    @Previewable @State var name = "EcoTouch Office"
    @Previewable @State var address = "Jl. Arjuna Utara No. 14D,\nTanjung Duren Selatan\nJakarta Barat"
    @Previewable @State var phone = ""
    @Previewable @State var email = ""
    @Previewable @State var imageData: Data?
    
    ProfileEditView(
        companyName: $name,
        companyAddress: $address,
        phoneNumber: $phone,
        email: $email,
        selectedImageData: $imageData
    )
}
