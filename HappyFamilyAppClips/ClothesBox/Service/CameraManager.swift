//
//  CameraManager.swift
//  Recap
//
//  Created by binc876 on 29/08/26.
//

import Foundation
import AVFoundation
import UIKit

final class CameraManager: NSObject {

    let session = AVCaptureSession()

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
            ) { granted in

                if granted {
                    self.configureAndStart()
                }
            }

        case .denied, .restricted:
            print("Camera permission denied")

        @unknown default:
            break
        }
    }

    private func configureAndStart() {

        DispatchQueue.global(
            qos: .userInitiated
        ).async {

            self.configureSession()

            guard !self.session.isRunning else {
                return
            }

            self.session.startRunning()
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

        DispatchQueue.global(
            qos: .userInitiated
        ).async {

            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }
}

extension CameraManager:
    AVCapturePhotoCaptureDelegate {

    func photoOutput(
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

        captureCompletion?(image)

        captureCompletion = nil
    }
}
