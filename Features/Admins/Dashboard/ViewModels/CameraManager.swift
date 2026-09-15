import AVFoundation

@MainActor
final class CameraManager: NSObject {
    let session = AVCaptureSession()

    private let metadataOutput = AVCaptureMetadataOutput()
    private let sessionQueue = DispatchQueue(label: "qr-scanner.session")
    private var isConfigured = false

    var onQRCodeDetected: ((String) -> Void)?

    func configure() -> Bool {
        guard !isConfigured else { return true }
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device)
        else {
            return false
        }

        session.beginConfiguration()
        guard session.canAddInput(input), session.canAddOutput(metadataOutput) else {
            session.commitConfiguration()
            return false
        }

        session.addInput(input)
        session.addOutput(metadataOutput)
        metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
        metadataOutput.metadataObjectTypes = [.qr]
        session.commitConfiguration()
        isConfigured = true
        return true
    }

    func start() {
        guard isConfigured else { return }
        let reference = CaptureSessionReference(value: session)
        sessionQueue.async { [reference] in
            if !reference.value.isRunning {
                reference.value.startRunning()
            }
        }
    }

    func stop() {
        let reference = CaptureSessionReference(value: session)
        sessionQueue.async { [reference] in
            if reference.value.isRunning {
                reference.value.stopRunning()
            }
        }
    }
}

extension CameraManager: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let code = metadataObjects
            .compactMap({ $0 as? AVMetadataMachineReadableCodeObject })
            .first(where: { $0.type == .qr }),
            let value = code.stringValue
        else {
            return
        }

        Task { @MainActor [weak self] in
            self?.onQRCodeDetected?(value)
        }
    }
}

private struct CaptureSessionReference: @unchecked Sendable {
    let value: AVCaptureSession
}
