//
//  ScanViewModel.swift
//  happyFamily
//
//  Created by Calzy Akmal Indyramdhani on 26/08/26.
//

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
    @Published private(set) var isTorchOn = false
    @Published var pickedItem: PhotosPickerItem? {
        didSet { Task { await scanPickedPhoto() } }
    }

    /// Fixed, not user-facing — donors shouldn't tune how suspicious the model is.
    private let sensitivity = AccessoryHead.shared.defaultSensitivity

    let camera = CameraSession()
    private let scanner = FeaturePrintScanner()

    var scannerModelVersion: String {
        "accessory-head-v\(AccessoryHead.shared.version)"
    }

    var safeResultMetadata: [String: String] {
        var metadata = [
            "accessory_count": String(result.present.count),
            "sensitivity": sensitivity,
        ]
        if let garmentType = result.garmentType {
            metadata["garment_type"] = garmentType.name
        }
        return metadata
    }

    /// How the current phase reads in the result sheet's vocabulary.
    /// `nil` while the camera is still the thing on screen.
    var outcome: ScanResultSheet.Outcome? {
        guard capturedImage != nil else { return nil }
        switch phase {
        case .aiming:
            return nil
        case .analyzing:
            return .checking
        case .rejected:
            return .multipleGarments
        case .reviewing:
            let accessories = accessoriesToRemove
            return accessories.isEmpty ? .success : .needsProcessing(accessories: accessories)
        }
    }

    /// Display names of the flagged accessories, deduplicated, in scan order.
    private var accessoriesToRemove: [String] {
        var seen: Set<String> = []
        return result.removable.compactMap { finding in
            let label = AccessoryHead.shared.displayName(for: finding.attribute)
            return seen.insert(label).inserted ? label : nil
        }
    }

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
            returnToAiming()
        }
    }

    func retake() {
        statusMessage = nil
        returnToAiming()
    }

    /// Back to the viewfinder, leaving `statusMessage` alone — a failing caller
    /// has just set it, and the hint panel is where it gets read.
    private func returnToAiming() {
        capturedImage = nil
        result = .empty
        phase = .aiming
        camera.start()
    }

    func toggleTorch() {
        isTorchOn.toggle()
        camera.setTorch(on: isTorchOn)
    }

    func flipCamera() {
        do {
            try camera.flipCamera()
            isTorchOn = false
        } catch {
            statusMessage = error.localizedDescription
        }
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
            returnToAiming()
            return
        }
        let scanner = self.scanner
        let level = sensitivity
        let outcome = await Task.detached(priority: .userInitiated) {
            Result { try scanner.scan(cgImage, sensitivity: level) }
        }.value

        switch outcome {
        case let .success(scanned):
            result = scanned
            phase = scanned.hasMultipleGarments ? .rejected : .reviewing
        case let .failure(error):
            statusMessage = "Gagal memproses foto: \(error)"
            returnToAiming()
        }
    }
}
