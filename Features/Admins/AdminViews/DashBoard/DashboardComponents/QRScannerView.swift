import AVFoundation
import SwiftUI

struct QRScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var scanner = QRScannerModel()

    var body: some View {
        NavigationStack {
            ZStack {
                QRScannerPreview(session: scanner.session)
                    .ignoresSafeArea()

                RoundedRectangle(cornerRadius: 20)
                    .stroke(.white, lineWidth: 3)
                    .frame(width: 260, height: 260)

                if let result = scanner.result {
                    VStack(spacing: 12) {
                        Text("QR Berhasil Dibaca")
                            .font(.headline)
                        Text(result)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .textSelection(.enabled)

                        Button("Tutup") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(20)
                    .frame(maxWidth: 320)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Tutup") {
                        dismiss()
                    }
                }
            }
            .navigationTitle("Scan QR")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await scanner.start()
            }
            .onDisappear {
                scanner.stop()
            }
            .alert("Akses Kamera Dibutuhkan", isPresented: $scanner.showPermissionAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Aktifkan akses kamera di Settings untuk scan QR.")
            }
        }
    }
}

@MainActor
final class QRScannerModel: NSObject, ObservableObject {
    let session = AVCaptureSession()
    @Published var result: String?
    @Published var showPermissionAlert = false

    private let metadataOutput = AVCaptureMetadataOutput()
    private var isConfigured = false

    func start() async {
        guard result == nil else { return }

        let permission = AVCaptureDevice.authorizationStatus(for: .video)
        if permission == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            guard granted else {
                showPermissionAlert = true
                return
            }
        } else if permission != .authorized {
            showPermissionAlert = true
            return
        }

        configureIfNeeded()
        guard !session.isRunning else { return }
        session.startRunning()
    }

    func stop() {
        guard session.isRunning else { return }
        session.stopRunning()
    }

    private func configureIfNeeded() {
        guard !isConfigured else { return }
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input),
              session.canAddOutput(metadataOutput) else {
            return
        }

        session.beginConfiguration()
        session.addInput(input)
        session.addOutput(metadataOutput)
        metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
        metadataOutput.metadataObjectTypes = [.qr]
        session.commitConfiguration()
        isConfigured = true
    }
}

extension QRScannerModel: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let code = metadataObjects
            .compactMap({ $0 as? AVMetadataMachineReadableCodeObject })
            .first(where: { $0.type == .qr }),
              let value = code.stringValue else {
            return
        }

        Task { @MainActor [weak self] in
            guard let self, self.result == nil else { return }
            self.result = value
            self.stop()
        }
    }
}

private struct QRScannerPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}
}

private final class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

#Preview {
    QRScannerView()
}
