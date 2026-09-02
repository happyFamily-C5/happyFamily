import SwiftUI
import MapKit
import CoreLocation

@MainActor
struct LocationPickerView: View {
    @Binding var selectedLocation: String?
    @Binding var selectedAddress: String?
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    
    @State private var showMapSheet: Bool = false
    
    var body: some View {
        Button(action: {
            showMapSheet = true
        }) {
            if let locationName = selectedLocation, !locationName.isEmpty {
                // MARK: - Tampilan Setelah Lokasi Dipilih (Sesuai Screenshot)
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color(.systemBackground))
                                .frame(width: 36, height: 36)
                            Image(systemName: "location.north.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                                .rotationEffect(.degrees(45))
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(locationName)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.primary)
                            
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
                    
                    // Snapshot Peta Kecil di Dalam Card
                    if let coordinate = selectedCoordinate {
                        Map(position: .constant(.region(MKCoordinateRegion(
                            center: coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                        )))) {
                            Marker("", coordinate: coordinate)
                                .tint(Color("3-DarkSoftCyan"))
                        }
                        .disabled(true) // Agar card tetap bisa diklik sebagai tombol utama
                        .frame(height: 140)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(.systemGray4), lineWidth: 0.5)
                        )
                    }
                }
                .padding(16)
                .background(Color(.systemGray6))
                .cornerRadius(24)
            } else {
                // MARK: - Tampilan Awal (Belum Pilih Lokasi)
                HStack(spacing: 12) {
                    Image(systemName: "location.north.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(45))
                    
                    Text("Pilih Lokasi")
                        .font(.system(size: 15, weight: .regular))
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
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 16)
        .sheet(isPresented: $showMapSheet) {
            MainMapPickerView(
                selectedLocation: $selectedLocation,
                selectedAddress: $selectedAddress,
                selectedCoordinate: $selectedCoordinate
            )
            // Swiping the map down used to dismiss the picker, which is easy to
            // trigger by accident while panning. Leaving is the back button's job.
            .interactiveDismissDisabled()
        }
    }
}

// MARK: - 1. Tampilan Peta Utama
struct MainMapPickerView: View {
    @Binding var selectedLocation: String?
    @Binding var selectedAddress: String?
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    @Environment(\.dismiss) var dismiss
    
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: -6.1754, longitude: 106.8272),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )
    @State private var showSearchSheet: Bool = false
    @State private var confirmedLocationName: String = ""
    @State private var confirmedAddress: String = ""
    @State private var tempCoordinate: CLLocationCoordinate2D?
    @State private var hasSelectedLocation: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                MapReader { proxy in
                    Map(position: $cameraPosition) {
                        UserAnnotation()
                        
                        if let tempCoordinate {
                            Marker("Lokasi Event", coordinate: tempCoordinate)
                                .tint(Color("3-DarkSoftCyan"))
                        }
                    }
                    .mapControls {
                        MapCompass()
                        MapUserLocationButton()
                    }
                    .simultaneousGesture(
                        SpatialTapGesture()
                            .onEnded { value in
                                if let coordinate = proxy.convert(value.location, from: .local) {
                                    selectLocation(at: coordinate)
                                }
                            }
                    )
                }
                .ignoresSafeArea()
                
                // Search Bar di Bawah (Kondisi Awal)
                if !hasSelectedLocation {
                    VStack {
                        HStack {
                            Button(action: { dismiss() }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.primary)
                                    .frame(width: 40, height: 40)
                                    .background(Color(.systemBackground))
                                    .clipShape(Circle())
                                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        
                        Spacer()
                    }
                    
                    VStack {
                        Spacer()
                        Button(action: { showSearchSheet = true }) {
                            HStack(spacing: 12) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)
                                Text("Cari lokasi event")
                                    .font(.system(size: 15))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Image(systemName: "mic.fill")
                                    .foregroundColor(.secondary)
                            }
                            .padding(16)
                            .background(Color(.systemBackground))
                            .cornerRadius(28)
                            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 2)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    }
                }
                
                // Search Bar di Atas & Panel Bawah (Setelah Lokasi Dipilih/Digeser)
                if hasSelectedLocation {
                    HStack(spacing: 12) {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)
                                .frame(width: 40, height: 40)
                                .background(Color(.systemBackground))
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                        }
                        
                        Button(action: { showSearchSheet = true }) {
                            HStack(spacing: 12) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)
                                Text("Cari lokasi event")
                                    .font(.system(size: 15))
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(.systemBackground))
                            .cornerRadius(24)
                            .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 2)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    
                    VStack {
                        Spacer()
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Lokasi Event")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.primary)
                                Text("Tap peta untuk menentukan titik lokasi.")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack(alignment: .center, spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color(.systemGray6))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: "location.north.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.primary)
                                        .rotationEffect(.degrees(45))
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(confirmedLocationName)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.primary)
                                    Text(confirmedAddress)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                                Spacer()
                            }
                            .padding(14)
                            .background(Color(.systemGray6))
                            .cornerRadius(16)
                            
                            PrimaryButton(title: "Gunakan Lokasi Ini") {
                                selectedLocation = confirmedLocationName
                                selectedAddress = confirmedAddress
                                selectedCoordinate = tempCoordinate
                                dismiss()
                            }
                        }
                        .padding(24)
                        .background(Color(.systemBackground))
                        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32))
                        .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: -5)
                    }
                    .ignoresSafeArea(edges: .bottom)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showSearchSheet) {
                LocationSearchModalView(
                    cameraPosition: $cameraPosition,
                    selectedName: $confirmedLocationName,
                    selectedAddress: $confirmedAddress,
                    selectedCoordinate: $tempCoordinate,
                    hasSelected: $hasSelectedLocation
                )
            }
        }
    }
    
    private func selectLocation(at coordinate: CLLocationCoordinate2D) {
        tempCoordinate = coordinate
        confirmedLocationName = "Titik Peta Dipilih"
        confirmedAddress = coordinateDescription(for: coordinate)
        hasSelectedLocation = true
        reverseGeocode(coordinate: coordinate)
    }
    
    private func reverseGeocode(coordinate: CLLocationCoordinate2D) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let geocoder = CLGeocoder()
        
        geocoder.reverseGeocodeLocation(location) { placemarks, _ in
            guard let placemark = placemarks?.first else { return }
            Task { @MainActor in
                confirmedLocationName = placemark.name ?? placemark.locality ?? "Titik Peta Dipilih"
                let street = placemark.thoroughfare ?? ""
                let city = placemark.locality ?? ""
                let combined = [street, city].filter { !$0.isEmpty }.joined(separator: ", ")
                confirmedAddress = combined.isEmpty ? coordinateDescription(for: coordinate) : combined
            }
        }
    }
    
    private func coordinateDescription(for coordinate: CLLocationCoordinate2D) -> String {
        "Lat: \(String(format: "%.4f", coordinate.latitude)), Lon: \(String(format: "%.4f", coordinate.longitude))"
    }
}

// MARK: - 2. Modal Sheet Pencarian Tempat
struct LocationSearchModalView: View {
    @Binding var cameraPosition: MapCameraPosition
    @Binding var selectedName: String
    @Binding var selectedAddress: String
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    @Binding var hasSelected: Bool
    
    @Environment(\.dismiss) var dismiss
    @State private var searchQuery: String = ""
    @State private var searchResults: [MKMapItem] = []
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 0) {
                List(searchResults, id: \.self) { item in
                    Button(action: {
                        selectedName = item.name ?? "Lokasi Kustom"
                        if let coord = coordinate(for: item) {
                            selectedCoordinate = coord
                            selectedAddress = addressDescription(for: item, fallbackCoordinate: coord)
                            cameraPosition = .region(MKCoordinateRegion(
                                center: coord,
                                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                            ))
                        }
                        hasSelected = true
                        dismiss()
                    }) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundColor(.secondary)
                                .padding(.top, 2)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name ?? "Lokasi")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.primary)
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
            }
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
        let search = MKLocalSearch(request: request)
        search.start { response, _ in
            guard let response = response else { return }
            Task { @MainActor in searchResults = response.mapItems }
        }
    }
    
    private func searchResultSubtitle(for mapItem: MKMapItem) -> String {
        guard let coordinate = coordinate(for: mapItem) else { return "" }
        return addressDescription(for: mapItem, fallbackCoordinate: coordinate)
    }
    
    private func coordinate(for mapItem: MKMapItem) -> CLLocationCoordinate2D? {
        mapItem.location.coordinate
    }
    
    private func addressDescription(for mapItem: MKMapItem, fallbackCoordinate: CLLocationCoordinate2D) -> String {
        mapItem.address?.shortAddress
            ?? mapItem.address?.fullAddress
            ?? mapItem.addressRepresentations?.fullAddress(includingRegion: true, singleLine: true)
            ?? coordinateDescription(for: fallbackCoordinate)
    }
    
    private func coordinateDescription(for coordinate: CLLocationCoordinate2D) -> String {
        "Lat: \(String(format: "%.4f", coordinate.latitude)), Lon: \(String(format: "%.4f", coordinate.longitude))"
    }
}

// MARK: - Preview
#Preview {
    @Previewable @State var loc: String? = "EcoTouch Office"
    @Previewable @State var addr: String? = "Duren Selatan, Jakarta Barat"
    @Previewable @State var coord: CLLocationCoordinate2D? = CLLocationCoordinate2D(latitude: -6.1754, longitude: 106.8272)
    
    return LocationPickerView(
        selectedLocation: $loc,
        selectedAddress: $addr,
        selectedCoordinate: $coord
    )
    .padding()
}
