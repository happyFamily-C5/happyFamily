import SwiftUI
import CoreLocation
import MapKit

struct EventSuccessView: View {
    var eventName: String = "Ecotoday"
    var eventDesc: String = "drop your unused shirt"
    var locationName: String = "EcoTouch Office"
    var locationAddress: String = "Duren Selatan, Jakarta Barat"
    var dateRange: String = "Rab, 9 Sept - 16 Sept 2026"
    var coordinate: CLLocationCoordinate2D? = CLLocationCoordinate2D(latitude: -6.1754, longitude: 106.8272)
    
    var onViewEventTapped: () -> Void
    var onReturnHomeTapped: () -> Void
    var onCloseTapped: () -> Void
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                
                // Spacer ini berfungsi mendorong konten agar turun ke tengah
                Spacer().frame(height: 100)
                
                // 1. Header Sukses (Ikon Centang & Judul)
                VStack(spacing: 16) {
                    ZStack {
                        Image(systemName: "sparkle")
                            .font(.system(size: 16))
                            .foregroundColor(.green)
                            .offset(x: -45, y: -25)
                        
                        Image(systemName: "sparkle")
                            .font(.system(size: 14))
                            .foregroundColor(.green)
                            .offset(x: 45, y: -15)
                        
                        Image(systemName: "circle.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.green)
                            .offset(x: -35, y: 30)
                        
                        ZStack {
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color.green)
                                .frame(width: 80, height: 80)
                                .rotationEffect(.degrees(15))
                            
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color.green.opacity(0.8))
                                .frame(width: 80, height: 80)
                                .rotationEffect(.degrees(45))
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(height: 90)
                    
                    Text("Acara berhasil Dibuat !")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primary)
                }
                
                // 2. Kartu Ringkasan & Peta
                VStack(spacing: 20) {
                    VStack(spacing: 6) {
                        Text(eventName)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                        
                        Text(eventDesc)
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
                        
                        Text(dateRange)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
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
                    .frame(height: 140)
                    .cornerRadius(16)
                }
                .padding(20)
                .background(Color(.systemBackground))
                .cornerRadius(24)
                .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
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
        .navigationBarHidden(true)
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
