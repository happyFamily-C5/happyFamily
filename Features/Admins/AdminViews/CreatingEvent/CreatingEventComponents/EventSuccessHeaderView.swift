import SwiftUI

struct EventSuccessHeaderView: View {
    var body: some View {
        VStack(spacing: 16) {
            // Ikon Sukses Badge dengan Aksen Bintang/Sparkle
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
                
                // Badge Utama Centang Hijau
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
            
            // Judul
            Text("Acara berhasil Dibuat !")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    EventSuccessHeaderView()
        .padding()
}
