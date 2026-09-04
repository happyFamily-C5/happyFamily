import SwiftUI

struct CancelEventSuccessView: View {
    var onReturnHomeTapped: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 18) {
                CancelEventStatusIcon(size: 64)
                
                VStack(spacing: 8) {
                    Text("Acara Dihapus")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Acara telah dihapus, notifikasi telah dikirimkan kepada para donatur")
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 36)
            
            Spacer()
            
            PrimaryButton(title: "Kembali ke Beranda", action: onReturnHomeTapped)
                .padding(.bottom, 10)
        }
        .background(Color(.systemBackground))
        .navigationBarHidden(true)
    }
}

#Preview {
    CancelEventSuccessView {
        print("Return")
    }
}
