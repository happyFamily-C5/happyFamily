import SwiftUI

struct QRScannerView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject var scanner = QRScannerViewModel()
    @State var showResult = false
    
    var body: some View {
        ZStack {
            QRScannerPreview(session: scanner.session)
                .ignoresSafeArea()
            
            Image(systemName: "viewfinder")
                .font(.system(size: 260, weight: .thin))
                .foregroundStyle(.black)
                .frame(width: 339, height: 339)
        }
        .onChange(of: scanner.result) { _ in
            showResult = true
        }
        .sheet(isPresented: $showResult, content: {
            NavigationStack {
                ScanResultView(scanner: scanner)
            }
        })
        .task {
            await scanner.start()
        }
        .onDisappear {
            scanner.stop()
        }
        .alert("Scanner Kamera", isPresented: $scanner.showCameraAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(scanner.cameraAlertMessage)
        }
    }
}

#Preview {
    NavigationStack {
        QRScannerView()
    }
}
