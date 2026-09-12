import AVFoundation
import SwiftUI

@MainActor
final class QRScannerViewModel: ObservableObject {
    let cameraManager: CameraManager

    @Published private(set) var result: String?
    @Published var showCameraAlert = false
    @Published private(set) var cameraAlertMessage = ""
    
    @Published var actualWeight = 1.0
    
    let actualWeightOpt: [Double] = stride(from: 1.0, through: 5.0, by: 0.1).map {
        (round($0 * 10) / 10)
    }

    var session: AVCaptureSession {
        cameraManager.session
    }

    init(cameraManager: CameraManager = CameraManager()) {
        self.cameraManager = cameraManager
        cameraManager.onQRCodeDetected = { [weak self] value in
            self?.handleScanResult(value)
        }
    }

    func start() async {
        guard result == nil else { return }

        let permission = AVCaptureDevice.authorizationStatus(for: .video)
        if permission == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            guard granted else {
                showAlert(with: "Aktifkan akses kamera di Settings untuk scan QR.")
                return
            }
        } else if permission != .authorized {
            showAlert(with: "Aktifkan akses kamera di Settings untuk scan QR.")
            return
        }

        guard cameraManager.configure() else {
            showAlert(with: "Kamera tidak bisa dipakai sekarang.")
            return
        }
        cameraManager.start()
    }

    func stop() {
        cameraManager.stop()
    }

    func prepareForNextScan() {
        result = nil
        actualWeight = 1.0
    }

    func restart() async {
        prepareForNextScan()
        await start()
    }

    private func handleScanResult(_ value: String) {
        guard result == nil else { return }
        result = value
        cameraManager.stop()
    }

    private func showAlert(with message: String) {
        cameraAlertMessage = message
        showCameraAlert = true
    }
}
