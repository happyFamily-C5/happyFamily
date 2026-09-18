import CoreLocation
import MapKit
import SwiftUI

struct EditEventBannerSection: View {
    let selectedImageData: Data?
    let remoteURL: URL?
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                EditEventBannerImage(imageData: selectedImageData, remoteURL: remoteURL)
                    .frame(height: 184)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                Label("Edit Sampul", systemImage: "photo")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color(.systemBackground).opacity(0.94))
                    .cornerRadius(10)
                    .padding(12)
            }
            .padding(.horizontal, 20)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EditEventInformationSection: View {
    let eventName: String
    let formattedDateRange: String
    let formattedTimeInfo: String
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Spacer(minLength: 0)

                VStack(alignment: .center, spacing: 6) {
                    Text(eventName.isEmpty ? "Nama acara belum diisi" : eventName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .center, spacing: 2) {
                        Text(formattedDateRange)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)

                        Text(formattedTimeInfo)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(Color(.systemGray6))
            .cornerRadius(16)
            .padding(.horizontal, 20)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EditEventCapacitySection: View {
    @Binding var donationCapacity: Int
    @Binding var isPickerOpen: Bool
    let capacityOptions: [Int]

    var body: some View {
        EditEventCard {
            VStack(alignment: .leading, spacing: 10) {
                EditEventPlainTitle(title: "Kapasitas Donasi")

                Button {
                    withAnimation(.snappy) {
                        isPickerOpen.toggle()
                    }
                } label: {
                    HStack {
                        Text("Jumlah")
                            .font(.system(size: 14))
                            .foregroundColor(.primary)

                        Spacer()

                        HStack(spacing: 4) {
                            Text("\(donationCapacity) kg")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)

                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                    }
                }
                .buttonStyle(PlainButtonStyle())

                if isPickerOpen {
                    Divider()

                    Picker("Kapasitas", selection: $donationCapacity) {
                        ForEach(capacityOptions, id: \.self) { amount in
                            Text("\(amount) kg").tag(amount)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 116)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }
}

struct EditEventCriteriaSection: View {
    let selectedCriteria: [String]
    let criteriaRows: [[String]]
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                EditEventRowTitle(title: "Kriteria Donasi")
                    .padding(.horizontal, 16)

                if selectedCriteria.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Belum ada kriteria")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)

                        Text("Pilih minimal 1 kriteria sebelum menyimpan.")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(red: 0.78, green: 0.12, blue: 0.12))
                    }
                    .padding(.horizontal, 16)
                } else {
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
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EditEventLocationSection: View {
    let selectedLocationName: String?
    let selectedLocationAddress: String?
    let selectedCoordinate: CLLocationCoordinate2D?
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                EditEventRowTitle(title: "Lokasi")
                    .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text((selectedLocationName?.isEmpty == false) ? selectedLocationName ?? "" : "Pilih lokasi event")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.primary)
                                .lineLimit(1)

                            Text((selectedLocationAddress?.isEmpty == false) ? selectedLocationAddress ?? "" : "Lokasi belum dipilih")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineLimit(2)
                        }

                        Spacer()
                    }

                    Map(initialPosition: .region(MKCoordinateRegion(
                        center: selectedCoordinate ?? CLLocationCoordinate2D(latitude: -6.1754, longitude: 106.8272),
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    ))) {
                        if let selectedCoordinate {
                            Marker("", coordinate: selectedCoordinate)
                                .tint(Color("3-DarkSoftCyan"))
                        }
                    }
                    .frame(height: 112)
                    .cornerRadius(14)
                    .disabled(true)
                }
                .padding(14)
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
                .padding(.horizontal, 16)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EditEventDescriptionSection: View {
    let eventDescription: String
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                EditEventRowTitle(title: "Detail Acara")
                    .padding(.horizontal, 16)

                Text(eventDescription.isEmpty ? "Tidak ada deskripsi" : eventDescription)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.primary)
                    .lineSpacing(4)
                    .lineLimit(8)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
                    .padding(.horizontal, 16)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
