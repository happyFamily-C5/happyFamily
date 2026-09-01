//
//  CameraScanViewModel.swift
//  Recap
//
//  Created by binc876 on 29/08/26.
//

import Observation
import UIKit

@MainActor
@Observable
final class CameraScanViewModel {

    let camera = CameraSession()

    private let analyzer = ClothingAnalyzer()

    var capturedImage: UIImage?

    var analysisState: AnalysisState = .idle

    var showResultSheet = false

    var analysisResult: ClothingAnalysis?

    /// Permission and hardware problems, shown over the preview. Analysis
    /// failures are not routed here — the result sheet reports those itself.
    var statusMessage: String?

    var isTorchOn = false

    enum AnalysisState {
        case idle
        case analyzing
        case completed
        case failed
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

    func stopCamera() {
        camera.stop()
    }

    func capturePhoto() async {
        do {
            await processImage(try await camera.capturePhoto())
        } catch {
            statusMessage = error.localizedDescription
        }
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

    func processImage(_ image: UIImage) async {

        capturedImage = image

        analysisState = .analyzing
        analysisResult = nil

        showResultSheet = true

        // The still frame is on screen behind the sheet from here on, so the
        // preview has nothing left to show until the user scans again.
        camera.stop()

        do {
            analysisResult = try await analyzer.analyze(image: image)
            analysisState = .completed
        } catch {
            analysisResult = nil
            analysisState = .failed
        }
    }

    func selectPhoto(_ image: UIImage) {
        Task { await processImage(image) }
    }

    func retry() {
        capturedImage = nil
        analysisResult = nil
        analysisState = .idle
        showResultSheet = false
        camera.start()
    }
}
