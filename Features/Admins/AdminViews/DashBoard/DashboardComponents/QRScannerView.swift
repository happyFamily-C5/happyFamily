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
            
            //            if let result = scanner.result {
            //                VStack(spacing: 12) {
            //                    Text("QR Berhasil Dibaca")
            //                        .font(.headline)
            //                    Text(result)
            //                        .font(.body)
            //                        .multilineTextAlignment(.center)
            //                        .textSelection(.enabled)
            //
            //                    Button("Tutup") {
            //                        dismiss()
            //                    }
            //                    .buttonStyle(.borderedProminent)
            //                }
            //                .padding(20)
            //                .frame(maxWidth: 320)
            //                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            //            }
        }
        .onChange(of: scanner.result) { _ in
            showResult = true
        }
        .sheet(isPresented: $showResult, content: {
            ScanResultView(scanner: scanner)
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
