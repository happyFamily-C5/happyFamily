//
//  ScanViewModel.swift
//  happyFamily
//
//  Created by Calzy Akmal Indyramdhani on 26/08/26.
//

import AVFoundation
import Combine
import Foundation
import PhotosUI
import SwiftUI

@MainActor
final class ScanViewModel: ObservableObject {
    enum Phase: Equatable {
        case aiming
        case analyzing
        case reviewing
        case rejected
    }

    @Published private(set) var phase: Phase = .aiming
    @Published private(set) var capturedImage: UIImage?
    @Published private(set) var result: AccessoryScanResult = .empty
    @Published private(set) var statusMessage: String?
    @Published var pickedItem: PhotosPickerItem? {
        didSet { Task { await scanPickedPhoto() } }
    }

    /// Fixed, not user-facing — donors shouldn't tune how suspicious the model is.
    private let sensitivity = AccessoryHead.shared.defaultSensitivity

    let camera = CameraSession()
    private let scanner = FeaturePrintScanner()

    func startCamera() async {
        guard await CameraSession.requestAccess() else {
            statusMessage = "Izin kamera ditolak. Aktifkan di Settings, atau pilih foto dari galeri."
            return
        }
        do {
            try camera.configure()
            camera.start()
            statusMessage = nil
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func capture() async {
        phase = .analyzing
        do {
            let photo = try await camera.capturePhoto()
            await analyze(photo)
        } catch {
            statusMessage = error.localizedDescription
            phase = .aiming
        }
    }

    func retake() {
        capturedImage = nil
        result = .empty
        statusMessage = nil
        phase = .aiming
        camera.start()
    }

    private func scanPickedPhoto() async {
        guard let pickedItem,
              let data = try? await pickedItem.loadTransferable(type: Data.self),
              let image = UIImage(data: data)
        else { return }
        phase = .analyzing
        await analyze(image)
    }

    private func analyze(_ image: UIImage) async {
        let normalized = image.normalizedUp()
        capturedImage = normalized
        camera.stop()

        guard let cgImage = normalized.cgImage else {
            statusMessage = "Foto tidak bisa dibaca."
            phase = .aiming
            return
        }
        let scanner = self.scanner
        let level = sensitivity
        let outcome = await Task.detached(priority: .userInitiated) {
            Result { try scanner.scan(.cgImage(cgImage), sensitivity: level) }
        }.value

        switch outcome {
        case let .success(scanned):
            result = scanned
            phase = scanned.hasMultipleGarments ? .rejected : .reviewing
        case let .failure(error):
            statusMessage = "Gagal memproses foto: \(error)"
            phase = .aiming
        }
    }
}
