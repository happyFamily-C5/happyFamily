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

    let cameraManager = CameraManager()
    let analyzer = ClothingAnalyzer()

    var capturedImage: UIImage?

    var analysisState: AnalysisState = .idle

    var showResultSheet = false

    var analysisResult: ClothingAnalysis?

    enum AnalysisState {
        case idle
        case analyzing
        case completed
        case failed
    }

    func startCamera() {
        cameraManager.requestPermissionAndStart()
    }

    func stopCamera() {
        cameraManager.stopSession()
    }

    func capturePhoto() {
        cameraManager.capturePhoto { [weak self] image in

            guard let self else {
                return
            }

            Task { @MainActor in
                self.processImage(image)
            }
        }
    }

    func processImage(_ image: UIImage) {

        capturedImage = image

        analysisState = .analyzing
        analysisResult = nil

        showResultSheet = true

        Task {

            let result = await analyzer.analyze(
                image: image
            )

            await MainActor.run {

                self.analysisResult = result

                self.analysisState = .completed
            }
        }
    }

    func selectPhoto(_ image: UIImage) {
        processImage(image)
    }

    func retry() {
        capturedImage = nil
        analysisResult = nil
        analysisState = .idle
        showResultSheet = false
    }
}
