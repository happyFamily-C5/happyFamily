import SwiftUI
import MapKit
import CoreLocation

struct MainMapPickerView: View {
    @Binding var selectedLocation: String?
    @Binding var selectedAddress: String?
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    @State private var isConfirmationPresented = false
    
    var onConfirm: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: -6.1754, longitude: 106.8272),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )
    @State private var showSearchSheet = false
    @State private var confirmedLocationName = ""
    @State private var confirmedAddress = ""
    @State private var tempCoordinate: CLLocationCoordinate2D?
    @State private var hasSelectedLocation = false

    var body: some View {
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

            if !hasSelectedLocation {
                VStack {
                    HStack {
                        backButton
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    Spacer()

                    searchButton(showMic: true)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                }
            }

            if hasSelectedLocation {
                VStack {
                    HStack(spacing: 12) {
                        backButton
                        searchButton(showMic: false)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    Spacer()

                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $isConfirmationPresented) {
            confirmationPanel
                .presentationDetents([.height(336)])
                .presentationDragIndicator(.visible)
                .presentationBackground(.clear)
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showSearchSheet) {
            LocationSearchModalView(
                cameraPosition: $cameraPosition,
                selectedName: $confirmedLocationName,
                selectedAddress: $confirmedAddress,
                selectedCoordinate: $tempCoordinate,
                hasSelected: $hasSelectedLocation
            )
        }
        .onAppear(perform: loadInitialSelection)
    }

    private var backButton: some View {
        Button(action: { dismiss() }) {
            Image(systemName: "chevron.left")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.primary)
                .frame(width: 40, height: 40)
                .background(Color(.systemBackground))
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        }
    }

    private func searchButton(showMic: Bool) -> some View {
        Button(action: { showSearchSheet = true }) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                Text("Cari lokasi event")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                Spacer()
                if showMic {
                    Image(systemName: "mic.fill")
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }

    private var confirmationPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Lokasi Event")
                    .font(.title2).bold()
                Text("Tap peta untuk menentukan titik lokasi.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 16) {
                Image(systemName: "location.fill")
                    .foregroundStyle(AppColor.primaryCyan)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .background(AppColor.secondaryCyan.opacity(0.5))
                    .clipShape(Circle())
        

                VStack(alignment: .leading, spacing: 4) {
                    Text(confirmedLocationName)
                        .font(.body).bold()
                    Text(confirmedAddress)
                        .font(.subheadline)
                
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(#colorLiteral(red: 0.9594197869, green: 0.9599153399, blue: 0.975127399, alpha: 1)))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            
            Spacer()
            
            Button {
                selectedLocation = confirmedLocationName
                selectedAddress = confirmedAddress
                selectedCoordinate = tempCoordinate
                if let onConfirm {
                    onConfirm()
                } else {
                    dismiss()
                }
            } label: {
                Text("Gunakan Lokasi Ini")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppColor.primaryCyan)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }

    private func loadInitialSelection() {
        guard !hasSelectedLocation, let selectedCoordinate else { return }

        tempCoordinate = selectedCoordinate
        confirmedLocationName = selectedLocation ?? "Titik Peta Dipilih"
        confirmedAddress = selectedAddress ?? coordinateDescription(for: selectedCoordinate)
        hasSelectedLocation = true
        cameraPosition = .region(MKCoordinateRegion(
            center: selectedCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
        isConfirmationPresented = true
    }

    private func selectLocation(at coordinate: CLLocationCoordinate2D) {
        tempCoordinate = coordinate
        confirmedLocationName = "Titik Peta Dipilih"
        confirmedAddress = coordinateDescription(for: coordinate)
        hasSelectedLocation = true
        isConfirmationPresented = true
        reverseGeocode(coordinate: coordinate)
    }

    private func reverseGeocode(coordinate: CLLocationCoordinate2D) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        CLGeocoder().reverseGeocodeLocation(location) { placemarks, _ in
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

#Preview("Main Map Picker") {
    @Previewable @State var location: String?
    @Previewable @State var address: String?
    @Previewable @State var coordinate: CLLocationCoordinate2D?

    NavigationStack {
        MainMapPickerView(
            selectedLocation: $location,
            selectedAddress: $address,
            selectedCoordinate: $coordinate
        )
    }
    .environment(AppRouter())
}
