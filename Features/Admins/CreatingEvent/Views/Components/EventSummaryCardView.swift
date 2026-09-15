import MapKit
import SwiftUI

struct EventSummaryCardView: View {
    let eventName: String
    let eventDescription: String
    let locationName: String
    let locationAddress: String
    let dateRangeString: String
    let coordinate: CLLocationCoordinate2D?

    var body: some View {
        VStack(spacing: 20) {
            // Informasi Teks Detail Acara
            VStack(spacing: 6) {
                Text(eventName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)

                Text(eventDescription)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Spacer().frame(height: 8)

                Text(locationName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                Text(locationAddress)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Spacer().frame(height: 8)

                Text(dateRangeString)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
            }

            // Pratinjau Peta (MapKit Statis)
            Map(initialPosition: .region(MKCoordinateRegion(
                center: coordinate ?? CLLocationCoordinate2D(latitude: -6.1754, longitude: 106.8272),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))) {
                if let coord = coordinate {
                    Marker("", coordinate: coord)
                }
            }
            .frame(height: 140)
            .cornerRadius(16)
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
        .padding(.horizontal, 16)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    EventSummaryCardView(
        eventName: "Ecotoday",
        eventDescription: "drop your unused shirt",
        locationName: "EcoTouch Office",
        locationAddress: "Duren Selatan, Jakarta Barat",
        dateRangeString: "Rab, 9 Sept - 16 Sept 2026",
        coordinate: CLLocationCoordinate2D(latitude: -6.1754, longitude: 106.8272)
    )
    .padding()
    .background(Color(.systemGray6))
}
