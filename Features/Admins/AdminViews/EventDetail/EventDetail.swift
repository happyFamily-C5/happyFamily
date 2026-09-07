import SwiftUI
import CoreLocation

struct EventDetailView: View {
    @State private var event: AdminEvent
    
    var onBackTapped: () -> Void
    var onShareTapped: () -> Void
    var onEditTapped: () -> Void
    var onEventUpdated: (AdminEvent) -> Void
    var onEventDeleted: (AdminEvent) -> Void
    
    init(
        event: AdminEvent,
        onBackTapped: @escaping () -> Void,
        onShareTapped: @escaping () -> Void,
        onEditTapped: @escaping () -> Void,
        onEventUpdated: @escaping (AdminEvent) -> Void = { _ in },
        onEventDeleted: @escaping (AdminEvent) -> Void = { _ in }
    ) {
        _event = State(initialValue: event)
        self.onBackTapped = onBackTapped
        self.onShareTapped = onShareTapped
        self.onEditTapped = onEditTapped
        self.onEventUpdated = onEventUpdated
        self.onEventDeleted = onEventDeleted
    }
    
    @State private var isShowingEditEvent: Bool = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    
                    // 1. Header Poster Atas (Banner & Tombol Navigasi)
                    EventDetailHeaderView(
                        bannerImage: event.bannerImage,
                        onBackTapped: onBackTapped,
                        onShareTapped: onShareTapped
                    )
                    .padding(.top, 8)
                    
                    // 2. Judul & Jadwal Acara (Digabung rapi)
                    EventHeaderSectionView(
                        title: event.name,
                        dateRangeText: event.formattedDateRange,
                        timeInfoText: event.formattedTimeInfo
                    )
                    
                    Spacer().frame(height: 8)
                    
                    // 3. Kartu Progress Pencapaian Donasi (250 kg)
                    DonationProgressBarView(
                        currentWeightText: "\(formattedKg(event.collectedKg)) kg",
                        targetWeightText: "Terkumpul dari \(event.capacityKg) kg",
                        progressValue: event.progress
                    )
                    
                    // 4. Kriteria Donasi (Menggunakan DonationTagChip yang sudah ada)
                    VStack(alignment: .leading, spacing: 12) {
                        EventDetailSectionTitle(title: "Kriteria Donasi")
                        
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(criteriaRows.enumerated()), id: \.offset) { _, row in
                                HStack(spacing: 8) {
                                    ForEach(row, id: \.self) { criteria in
                                        DonationTagChip(title: criteria, isSelected: true, isCompact: true) {}
                                    }
                                    Spacer(minLength: 0)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    // 5. Lokasi & Peta MapKit
                    VStack(alignment: .leading, spacing: 10) {
                        EventDetailSectionTitle(title: "Lokasi")
                        
                        EventLocationCardView(
                            locationName: event.locationName,
                            address: event.locationAddress,
                            distanceText: "",
                            coordinate: event.coordinate
                        )
                    }
                    
                    // 6. Detail Acara & Teks Panjang
                    VStack(alignment: .leading, spacing: 10) {
                        EventDetailSectionTitle(title: "Detail Acara")
                        
                        Text(descriptionText)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.primary)
                            .lineSpacing(4)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
                            .padding(.horizontal, 16)
                    }
                    
                    // Spacer bawah agar konten tidak tertutup tombol mengambang
                    Spacer().frame(height: 84)
                }
            }
            
            // 7. Tombol "Edit Acara" di Bagian Bawah (Menggunakan PrimaryButton milikmu)
            VStack {
                PrimaryButton(title: "Edit Acara") {
                    onEditTapped()
                    isShowingEditEvent = true
                }
            }
            .padding(.vertical, 8)
            .background(Color(.systemBackground).opacity(0.95))
        }
        .edgesIgnoringSafeArea(.bottom)
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $isShowingEditEvent) {
            EditEventView(
                event: event,
                onSave: { updatedEvent in
                    event = updatedEvent
                    onEventUpdated(updatedEvent)
                },
                onDelete: {
                    isShowingEditEvent = false
                    onEventDeleted(event)
                }
            )
        }

    }
    
    private var descriptionText: String {
        event.description.isEmpty ? "Tidak ada deskripsi" : event.description
    }
    
    private var criteriaRows: [[String]] {
        stride(from: 0, to: event.donationCriteria.count, by: 3).map { startIndex in
            Array(event.donationCriteria[startIndex..<min(startIndex + 3, event.donationCriteria.count)])
        }
    }
    
    private func formattedKg(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.1f", value)
    }
}

#Preview {
    NavigationStack {
        EventDetailView(
            event: .preview,
            onBackTapped: { print("Back") },
            onShareTapped: { print("Share") },
            onEditTapped: { print("Edit Acara") }
        )
    }
}

private extension AdminEvent {
    static var preview: AdminEvent {
        AdminEvent(
            name: "Ecotoday | drop your unused shirt",
            description: "drop your unused shirt",
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .day, value: 6, to: Date()) ?? Date(),
            locationName: "EcoTouch Office",
            locationAddress: "Duren Selatan, Jakarta Barat",
            coordinate: CLLocationCoordinate2D(latitude: -6.1754, longitude: 106.8272),
            operationalMode: "Hari kerja",
            activeDays: [true, true, true, true, true, false, false],
            startTime: Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date(),
            endTime: Calendar.current.date(from: DateComponents(hour: 16, minute: 0)) ?? Date(),
            donationCriteria: ["Katun", "Linen", "Wol", "Tencel", "Rayon"],
            capacityKg: 500,
            collectedKg: 250,
            bannerImageData: nil
        )
    }
}
