//
//  CameraSession.swift
//  happyFamily
//
//  Created by Calzy Akmal Indyramdhani on 26/08/26.
//

import AVFoundation
import Foundation
import UIKit

/// AVFoundation doesn't declare `AVCaptureSession` as `Sendable`, although
/// starting and stopping this owned instance is serialized on one private queue.
private struct CaptureSessionReference: @unchecked Sendable {
    let value: AVCaptureSession
}

@MainActor
final class CameraSession: NSObject {
    enum SetupError: LocalizedError {
        case noCamera
        case cannotAddInput
        case captureFailed

        var errorDescription: String? {
            switch self {
            case .noCamera: "Tidak ada kamera di perangkat ini."
            case .cannotAddInput: "Kamera tidak bisa dipakai sekarang."
            case .captureFailed: "Gagal mengambil foto."
            }
        }
    }

    let session = AVCaptureSession()

    private let queue = DispatchQueue(label: "camera.session")
    private let photoOutput = AVCapturePhotoOutput()
    private var photoCaptureDelegate: PhotoCaptureDelegate?
    private(set) var position: AVCaptureDevice.Position = .back
    private var activeDevice: AVCaptureDevice?

    func configure() throws {
        guard session.inputs.isEmpty else { return }
        session.beginConfiguration()
        session.sessionPreset = .photo
        do {
            try addInput(for: position)
        } catch {
            session.commitConfiguration()
            throw error
        }
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        session.commitConfiguration()
    }

    func flipCamera() throws {
        let newPosition: AVCaptureDevice.Position = position == .back ? .front : .back
        session.beginConfiguration()
        let previousInputs = session.inputs
        previousInputs.forEach(session.removeInput)
        do {
            try addInput(for: newPosition)
        } catch {
            previousInputs.forEach(session.addInput)
            session.commitConfiguration()
            throw error
        }
        position = newPosition
        session.commitConfiguration()
    }

    func setTorch(on: Bool) {
        guard let activeDevice, activeDevice.hasTorch else { return }
        try? activeDevice.lockForConfiguration()
        activeDevice.torchMode = on ? .on : .off
        activeDevice.unlockForConfiguration()
    }

    private func addInput(for position: AVCaptureDevice.Position) throws {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device)
        else { throw SetupError.noCamera }
        guard session.canAddInput(input) else { throw SetupError.cannotAddInput }
        session.addInput(input)
        activeDevice = device
    }

    func start() {
        guard !session.isRunning else { return }
        let reference = CaptureSessionReference(value: session)
        queue.async { [reference] in reference.value.startRunning() }
    }

    func stop() {
        guard session.isRunning else { return }
        let reference = CaptureSessionReference(value: session)
        queue.async { [reference] in reference.value.stopRunning() }
    }

    func capturePhoto() async throws -> UIImage {
        defer { photoCaptureDelegate = nil }
        return try await withCheckedThrowingContinuation { continuation in
            let delegate = PhotoCaptureDelegate(continuation: continuation)
            photoCaptureDelegate = delegate
            let settings = AVCapturePhotoSettings()
            photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }

    static func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: true
        case .notDetermined: await AVCaptureDevice.requestAccess(for: .video)
        default: false
        }
    }
}

private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let continuation: CheckedContinuation<UIImage, any Error>

    init(continuation: CheckedContinuation<UIImage, any Error>) {
        self.continuation = continuation
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            continuation.resume(throwing: error)
            return
        }
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
            continuation.resume(throwing: CameraSession.SetupError.captureFailed)
            return
        }
        continuation.resume(returning: image)
    }
}

extension UIImage {
    /// Without this, highlight tiles land 90° off — Vision reads raw CGImage pixels,
    /// ignoring the camera photo's imageOrientation.
    func normalizedUp() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
