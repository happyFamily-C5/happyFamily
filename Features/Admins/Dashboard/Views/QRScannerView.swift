import SwiftUI

struct QRScannerView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject var scanner = QRScannerViewModel()
    @State var showResult = false
    @State private var shouldRestartAfterResult = true

    var body: some View {
        ZStack {
            QRScannerPreview(session: scanner.session)
                .ignoresSafeArea()

            Image(systemName: "viewfinder")
                .font(.system(size: 260, weight: .thin))
                .foregroundStyle(.black)
                .frame(width: 339, height: 339)
        }
        .onChange(of: scanner.result) { _, result in
            if result != nil {
                showResult = true
            }
        }
        .sheet(isPresented: $showResult, onDismiss: handleResultDismissal) {
            NavigationStack {
                ScanResultView(
                    scanner: scanner,
                    onRetry: { showResult = false },
                    onFinished: {
                        shouldRestartAfterResult = false
                        scanner.prepareForNextScan()
                        showResult = false
                        dismiss()
                    }
                )
            }
        }
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

    private func handleResultDismissal() {
        guard shouldRestartAfterResult else {
            shouldRestartAfterResult = true
            return
        }
        Task { await scanner.restart() }
    }
}

#Preview {
    NavigationStack {
        QRScannerView()
    }
}
