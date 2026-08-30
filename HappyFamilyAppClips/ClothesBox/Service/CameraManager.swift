//
//  CameraManager.swift
//  Recap
//
//  Created by binc876 on 29/08/26.
//

import AVFoundation
import Foundation
import UIKit

/// AVFoundation does not declare `AVCaptureSession` as `Sendable`, although
/// starting and stopping this owned instance is serialized on one private queue.
private struct CaptureSessionReference: @unchecked Sendable {
    let value: AVCaptureSession
}

@MainActor
final class CameraManager: NSObject {

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(
        label: "clothes-box.camera.session",
        qos: .userInitiated
    )

    private let photoOutput = AVCapturePhotoOutput()

    private var captureCompletion: ((UIImage) -> Void)?

    private var isConfigured = false

    func requestPermissionAndStart() {

        switch AVCaptureDevice.authorizationStatus(
            for: .video
        ) {

        case .authorized:
            configureAndStart()

        case .notDetermined:

            AVCaptureDevice.requestAccess(
                for: .video
            ) { [weak self] granted in

                if granted {
                    Task { @MainActor [weak self] in
                        self?.configureAndStart()
                    }
                }
            }

        case .denied, .restricted:
            print("Camera permission denied")

        @unknown default:
            break
        }
    }

    private func configureAndStart() {

        configureSession()

        let reference = CaptureSessionReference(
            value: session
        )

        sessionQueue.async { [reference] in

            guard !reference.value.isRunning else {
                return
            }

            reference.value.startRunning()
        }
    }

    private func configureSession() {

        guard !isConfigured else {
            return
        }

        session.beginConfiguration()

        session.sessionPreset = .photo

        guard let camera = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back
        ) else {

            session.commitConfiguration()
            return
        }

        do {

            let input = try AVCaptureDeviceInput(
                device: camera
            )

            if session.canAddInput(input) {
                session.addInput(input)
            }

            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
            }

            session.commitConfiguration()

            isConfigured = true

        } catch {

            session.commitConfiguration()

            print(
                "Camera configuration error:",
                error
            )
        }
    }

    func capturePhoto(
        completion: @escaping (UIImage) -> Void
    ) {

        captureCompletion = completion

        let settings = AVCapturePhotoSettings()

        photoOutput.capturePhoto(
            with: settings,
            delegate: self
        )
    }

    func stopSession() {

        let reference = CaptureSessionReference(
            value: session
        )

        sessionQueue.async { [reference] in

            if reference.value.isRunning {
                reference.value.stopRunning()
            }
        }
    }
}

extension CameraManager:
    AVCapturePhotoCaptureDelegate {

    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {

        guard error == nil else {
            print(
                "Photo capture error:",
                error!
            )
            return
        }

        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data)
        else {
            return
        }

        Task { @MainActor [weak self] in
            self?.captureCompletion?(image)
            self?.captureCompletion = nil
        }
    }
}
