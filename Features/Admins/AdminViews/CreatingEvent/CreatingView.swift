import SwiftUI
import PhotosUI
import MapKit
import CoreLocation

struct CreatingView: View {
    @Environment(\.dismiss) var dismiss
    @FocusState private var focusedField: FocusedField?
    
    // Callback untuk mengirim data event baru kembali ke Dashboard
    var onEventCreated: (AdminEvent) -> Void
    
    // State untuk alur pembuatan event (Step 1 sampai 3)
    @State private var currentStep: Int = 1
    @State private var totalSteps: Int = 3
    
    // State untuk Form Step 1 (Informasi Dasar)
    @State private var eventName: String = ""
    @State private var eventDescription: String = ""
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedBannerImage: Image? = nil
    @State private var selectedImageData: Data? = nil
    
    // State untuk Form Step 2 (Jadwal dan Lokasi)
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Calendar.current.date(byAdding: .day, value: 6, to: Date()) ?? Date()
    @State private var selectedLocationName: String? = nil
    @State private var selectedLocationAddress: String? = nil
    @State private var selectedCoordinate: CLLocationCoordinate2D? = nil
    @State private var operationalMode: String = "Akhir Pekan"
    @State private var activeDays: [Bool] = [true, false, false, false, false, false, true]
    @State private var startTime: Date = Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date()
    @State private var endTime: Date = Calendar.current.date(from: DateComponents(hour: 16, minute: 0)) ?? Date()
    
    // State untuk Popup Date Picker Native iOS
    @State private var activeDateSheet: DateFieldTarget? = nil
    enum DateFieldTarget {
        case start, end
    }
    
    private enum FocusedField {
        case eventName
        case eventDescription
    }
    
    // State untuk Form Step 3 (Kriteria Donasi & Kapasitas)
    let availableCategories: [String] = [
        "Katun", "Linen", "Rayon", "Wol",
        "Tencel", "Sutra", "Tidak Elastis",
        "Denim", "Tidak berenda",
        "Poliester"
    ]
    @State private var selectedCategories: Set<String> = []
    @State private var donationCapacity: Int = 10
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            // MARK: - 1. Header dengan Progress Bar Segmen Sesuai Step Aktif
            FormHeaderView(
                currentStep: currentStep,
                totalSteps: totalSteps,
                stepTitle: stepTitleText,
                onBackTapped: {
                    if currentStep > 1 {
                        currentStep -= 1
                    } else {
                        dismiss()
                    }
                }
            )
            .padding(.top, 8)
            
            // MARK: - 2. Konten Berdasarkan Step Aktif
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    
                    if currentStep == 1 {
                        step1ContentView
                    } else if currentStep == 2 {
                        step2ContentView
                    } else if currentStep == 3 {
                        step3ContentView
                    }
                    
                }
                .padding(.vertical, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            
            // MARK: - 3. Tombol Aksi Bawah (Lanjut / Selesai)
            VStack {
                PrimaryButton(title: currentStep == totalSteps ? "Buat Acara" : "Lanjut") {
                    if currentStep < totalSteps {
                        currentStep += 1
                    } else {
                        // Buat objek event baru dari data form
                        let newEvent = AdminEvent(
                            name: eventName,
                            startDate: startDate,
                            endDate: endDate,
                            capacityKg: donationCapacity,
                            collectedKg: 0,
                            bannerImageData: selectedImageData
                        )
                        // Kirim data ke DashboardView
                        onEventCreated(newEvent)
                        
                        print("Event berhasil dibuat!")
                        dismiss()
                    }
                }
                .disabled(!isCurrentStepValid)
                .opacity(isCurrentStepValid ? 1.0 : 0.6)
            }
            .padding(.bottom, 16)
        }
        .contentShape(Rectangle())
        .onTapGesture { focusedField = nil }
        .navigationBarHidden(true)
        // MARK: - Sheet Date Picker dengan Logika Batasan Tanggal
        .sheet(item: $activeDateSheet) { target in
//            NavigationStack {
                VStack {
                    DatePicker(
                        target == .start ? "Pilih Tanggal Mulai" : "Pilih Tanggal Selesai",
                        selection: dateBinding(for: target),
                        in: dateRange(for: target),
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.graphical)
                    .padding()
                    Spacer()
                }
                .navigationTitle(target == .start ? "Tanggal Mulai" : "Tanggal Selesai")
                .navigationBarTitleDisplayMode(.inline)
//            }
            .presentationDetents([.medium])
        }
        .onChange(of: startTime) { _, newStart in
            if endTime < newStart {
                endTime = newStart
            }
        }
        .onChange(of: endTime) { _, newEnd in
            if newEnd < startTime {
                startTime = newEnd
            }
        }
    }
    
    // Judul Header Dinamis
    private var stepTitleText: String {
        switch currentStep {
        case 1: return "Informasi Dasar"
        case 2: return "Jadwal dan lokasi"
        case 3: return "Kriteria Donasi"
        default: return "Tambah Acara"
        }
    }
    
    // Validasi apakah tombol Lanjut boleh diklik
    private var isCurrentStepValid: Bool {
        switch currentStep {
        case 1:
            return !eventName.isEmpty
        case 2:
            let isDateValid = endDate >= startDate
            let isTimeValid = endTime >= startTime
            return selectedLocationName != nil && !selectedLocationName!.isEmpty && isDateValid && isTimeValid
        case 3:
            return !selectedCategories.isEmpty
        default:
            return true
        }
    }
    
    // MARK: - Tampilan Step 1
    private var step1ContentView: some View {
        VStack(alignment: .leading, spacing: 28) {
            ZStack(alignment: .bottomTrailing) {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    MainActor.assumeIsolated {
                        ImagePickerCardView(
                            selectedImage: selectedBannerImage,
                            onAddTapped: {},
                            onDeleteTapped: {}
                        )
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                if selectedBannerImage != nil {
                    Button {
                        selectedBannerImage = nil
                        selectedItem = nil
                        selectedImageData = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 28)
                    .padding(.bottom, 12)
                }
            }
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        await MainActor.run {
                            selectedImageData = data
                            selectedBannerImage = Image(uiImage: uiImage)
                        }
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Nama Acara")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    TextField("Cth: Ecoprint Festival 2026", text: $eventName)
                        .focused($focusedField, equals: .eventName)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .eventDescription
                        }
                        .padding(16)
                        .background(Color(.systemGray6))
                        .cornerRadius(24)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    focusedField = .eventName
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Deskripsi Acara (optional)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $eventDescription)
                            .focused($focusedField, equals: .eventDescription)
                            .padding(12)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                        
                        if eventDescription.isEmpty {
                            Text("Tuliskan deskripsi singkat mengenai acara...")
                                .foregroundColor(Color(.placeholderText))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 20)
                                .allowsHitTesting(false)
                        }
                    }
                    .frame(height: 130)
                    .background(Color(.systemGray6))
                    .cornerRadius(24)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    focusedField = .eventDescription
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Tampilan Step 2
    private var step2ContentView: some View {
        VStack(alignment: .leading, spacing: 20) {
            DateTimeRangeCardView(
                startDateString: formattedDate(startDate),
                endDateString: formattedDate(endDate),
                onStartTap: {
                    activeDateSheet = .start
                },
                onEndTap: {
                    activeDateSheet = .end
                }
            )
            .padding(.horizontal, 16)
            
            LocationPickerView(
                selectedLocation: $selectedLocationName,
                selectedAddress: $selectedLocationAddress,
                selectedCoordinate: $selectedCoordinate
            )
            
            OperationalScheduleCardView(
                selectedPreset: $operationalMode,
                activeDays: $activeDays,
                startTime: $startTime,
                endTime: $endTime
            )
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Tampilan Step 3 (Kriteria Donasi & Kapasitas Donasi)
    private var step3ContentView: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Tentukan Kriteria\nDonasi")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                    .lineSpacing(4)
                
                Text("Pilih kategori-kategori pakaian yang akan anda terima sebagai donasi")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            
            // Grid Tag Chip Kategori
            AdminFlowLayout(spacing: 10) {
                ForEach(availableCategories, id: \.self) { category in
                    let isSelected = selectedCategories.contains(category)
                    
                    DonationTagChip(title: category, isSelected: isSelected) {
                        if isSelected {
                            selectedCategories.remove(category)
                        } else {
                            selectedCategories.insert(category)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            
            
            DonationCapacityCardView(selectedCapacity: $donationCapacity)
                .padding(.horizontal, 20)
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).year())
    }
    
    private func dateBinding(for target: DateFieldTarget) -> Binding<Date> {
        switch target {
        case .start:
            return Binding(
                get: { startDate },
                set: { newValue in
                    startDate = min(newValue, endDate)
                }
            )
        case .end:
            return Binding(
                get: { endDate },
                set: { newValue in
                    endDate = max(newValue, startDate)
                }
            )
        }
    }
    
    private func dateRange(for target: DateFieldTarget) -> ClosedRange<Date> {
        switch target {
        case .start:
            return Date.distantPast...endDate
        case .end:
            return startDate...Date.distantFuture
        }
    }
}

extension CreatingView.DateFieldTarget: Identifiable {
    var id: Self { self }
}

#Preview {
    NavigationStack {
        CreatingView { _ in }
    }
}
