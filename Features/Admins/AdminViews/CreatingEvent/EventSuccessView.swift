import SwiftUI
import CoreLocation
import MapKit

struct EventSuccessView: View {
    var eventName: String = "Ecoday\n drop your unused shirt"
    var locationName: String = "EcoTouch Office"
    var locationAddress: String = "Duren Selatan, Jakarta Barat"
    var dateRange: String = "Rab, 9 Sept - 16 Sept 2026"
    var coordinate: CLLocationCoordinate2D? = CLLocationCoordinate2D(latitude: -6.1754, longitude: 106.8272)
    
    var onViewEventTapped: () -> Void
    var onReturnHomeTapped: () -> Void
    var onCloseTapped: () -> Void
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 42) {
                VStack(spacing: 32) {
                    VStack(spacing: 8) {
                        Image("Acc")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 152)
                        
                        Text("Acara berhasil Dibuat !")
                            .font(.title).bold()
                            .foregroundColor(.primary)
                    }
                    
                    // 2. Kartu Ringkasan & Peta
                        VStack(spacing: 16) {
                            Text(eventName)
                                .font(.title2).bold()
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)
                            
                            VStack {
                                Text(locationName)
                                    .font(.body).bold()
                                Text(locationAddress)
                                    .font(.subheadline)
                            }
                            
                            Text(dateRange)
                                .font(.subheadline).bold()
                        }
                    
                    // Peta Statis MapKit
                    Map(initialPosition: .region(MKCoordinateRegion(
                        center: coordinate ?? CLLocationCoordinate2D(latitude: -6.1754, longitude: 106.8272),
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    ))) {
                        if let coord = coordinate {
                            Marker("", coordinate: coord)
                        }
                    }
                    .frame(height: 164)
                    .cornerRadius(16)
                }
                .padding(20)
                .cornerRadius(24)
                .padding(.horizontal, 16)
                
                // 3. Tombol Aksi Bawah
                VStack(spacing: 12) {
                    PrimaryButton(title: "Lihat Halaman Acara") {
                        onViewEventTapped()
                    }
                    
                    Button(action: onReturnHomeTapped) {
                        Text("Kembali ke Beranda")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(.systemGray6).opacity(0.8))
                            .cornerRadius(30)
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 32)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar{
            ToolbarItem(placement: .topBarTrailing) {
                Button{
                    
                }label: {
                    Image(systemName: "xmark")
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        EventSuccessView(
            onViewEventTapped: { print("Lihat acara") },
            onReturnHomeTapped: { print("Kembali ke beranda") },
            onCloseTapped: { print("Kembali ke step 3") }
        )
    }
}
