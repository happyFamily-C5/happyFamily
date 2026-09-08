import SwiftUI
import MapKit

struct LocationSearchModalView: View {
    @Binding var cameraPosition: MapCameraPosition
    @Binding var selectedName: String
    @Binding var selectedAddress: String
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    @Binding var hasSelected: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var searchQuery = ""
    @State private var searchResults: [MKMapItem] = []

    var body: some View {
        NavigationStack {
            List(searchResults, id: \.self) { item in
                Button {
                    selectedName = item.name ?? "Lokasi Kustom"
                    let coordinate = item.location.coordinate
                    selectedCoordinate = coordinate
                    selectedAddress = addressDescription(for: item, fallbackCoordinate: coordinate)
                    cameraPosition = .region(MKCoordinateRegion(
                        center: coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    ))
                    hasSelected = true
                    dismiss()
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name ?? "Lokasi")
                                .font(.system(size: 15, weight: .semibold))
                            Text(searchResultSubtitle(for: item))
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Cari Lokasi")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchQuery, prompt: "Cari lokasi event")
            .onChange(of: searchQuery) { _, newValue in
                searchPlaces(query: newValue)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Batal") { dismiss() }
                }
            }
        }
    }

    private func searchPlaces(query: String) {
        guard !query.isEmpty else {
            searchResults.removeAll()
            return
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        MKLocalSearch(request: request).start { response, _ in
            guard let response else { return }
            Task { @MainActor in
                searchResults = response.mapItems
            }
        }
    }

    private func searchResultSubtitle(for mapItem: MKMapItem) -> String {
        addressDescription(for: mapItem, fallbackCoordinate: mapItem.location.coordinate)
    }

    private func addressDescription(
        for mapItem: MKMapItem,
        fallbackCoordinate: CLLocationCoordinate2D
    ) -> String {
        mapItem.address?.shortAddress
            ?? mapItem.address?.fullAddress
            ?? mapItem.addressRepresentations?.fullAddress(includingRegion: true, singleLine: true)
            ?? "Lat: \(String(format: "%.4f", fallbackCoordinate.latitude)), Lon: \(String(format: "%.4f", fallbackCoordinate.longitude))"
    }
}
