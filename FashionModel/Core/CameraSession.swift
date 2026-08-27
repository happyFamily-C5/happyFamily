//
//  CameraSession.swift
//  happyFamily
//
//  Created by Calzy Akmal Indyramdhani on 26/08/26.
//

import AVFoundation
import Foundation
import UIKit

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
    private var captureContinuation: CheckedContinuation<UIImage, Error>?
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
        queue.async { [session] in session.startRunning() }
    }

    func stop() {
        guard session.isRunning else { return }
        queue.async { [session] in session.stopRunning() }
    }

    func capturePhoto() async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            captureContinuation = continuation
            let settings = AVCapturePhotoSettings()
            photoOutput.capturePhoto(with: settings, delegate: self)
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

extension CameraSession: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        defer { captureContinuation = nil }
        if let error {
            captureContinuation?.resume(throwing: error)
            return
        }
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
            captureContinuation?.resume(throwing: SetupError.captureFailed)
            return
        }
        captureContinuation?.resume(returning: image)
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
