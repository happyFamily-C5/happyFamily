import MapKit
import SwiftUI

struct EventLocationCardView: View {
    let locationName: String
    let address: String
    let distanceText: String // Contoh: "1.4 km"
    let coordinate: CLLocationCoordinate2D?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Baris Atas: Nama Lokasi & Jarak
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(locationName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.primary)

                    Text(address)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if !distanceText.isEmpty {
                    Text(distanceText)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                }
            }

            // Peta Statis MapKit Native
            Map(initialPosition: .region(MKCoordinateRegion(
                center: coordinate ?? CLLocationCoordinate2D(latitude: -6.1754, longitude: 106.8272),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))) {
                if let coord = coordinate {
                    Marker("", coordinate: coord)
                }
            }
            .frame(height: 112)
            .cornerRadius(14)
            .disabled(true) // Membuat peta read-only / tidak bisa digeser-geser di card detail
        }
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
        .padding(.horizontal, 16)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    EventLocationCardView(
        locationName: "EcoTouch Office",
        address: "Jl. Arjuna Utara No.14D, RT.1/RW.1, Tj. Duren Sel., Kec. Grogol petamburan...",
        distanceText: "1.4 km",
        coordinate: CLLocationCoordinate2D(latitude: -6.1754, longitude: 106.8272)
    )
    .padding()
    .background(Color(.systemGray6))
}
