import CoreLocation
import MapKit
import SwiftUI

@MainActor
struct LocationPickerView: View {
    @Environment(AppRouter.self) private var router
    @Binding var selectedLocation: String?
    @Binding var selectedAddress: String?
    @Binding var selectedCoordinate: CLLocationCoordinate2D?

    var body: some View {
        Button {
            router.openMapPicker(
                location: selectedLocation,
                address: selectedAddress,
                coordinate: selectedCoordinate
            )
        } label: {
            if let locationName = selectedLocation, !locationName.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color(.systemBackground))
                                .frame(width: 36, height: 36)
                            Image(systemName: "location.north.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .rotationEffect(.degrees(45))
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(locationName)
                                .font(.system(size: 16, weight: .bold))
                            Text(selectedAddress ?? "")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                    }

                    if let coordinate = selectedCoordinate {
                        Map(position: .constant(.region(MKCoordinateRegion(
                            center: coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                        )))) {
                            Marker("", coordinate: coordinate)
                                .tint(Color("3-DarkSoftCyan"))
                        }
                        .disabled(true)
                        .frame(maxWidth: .infinity)
                        .frame(height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(24)
                .contentShape(RoundedRectangle(cornerRadius: 24))
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "location.north.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(45))
                    Text("Pilih Lokasi")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(Color(.systemGray6))
                .cornerRadius(24)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .onChange(of: router.mapPickerSession.revision) { _, _ in
            selectedLocation = router.mapPickerSession.selectedLocation
            selectedAddress = router.mapPickerSession.selectedAddress
            selectedCoordinate = router.mapPickerSession.selectedCoordinate
        }
    }
}

#Preview {
    @Previewable @State var location: String? = "EcoTouch Office"
    @Previewable @State var address: String? = "Duren Selatan, Jakarta Barat"
    @Previewable @State var coordinate: CLLocationCoordinate2D? = CLLocationCoordinate2D(
        latitude: -6.1754,
        longitude: 106.8272
    )

    LocationPickerView(
        selectedLocation: $location,
        selectedAddress: $address,
        selectedCoordinate: $coordinate
    )
    .environment(AppRouter())
    .padding()
}
