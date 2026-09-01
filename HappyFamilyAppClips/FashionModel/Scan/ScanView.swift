//
//  ScanView.swift
//  happyFamily
//
//  Created by Calzy Akmal Indyramdhani on 26/08/26.
//

import SwiftUI

struct ScanView: View {
    @StateObject private var viewModel = ScanViewModel()
    @Environment(\.dismiss) private var dismiss

    private static let clothingFrameImage = UIImage.bundled("clothing_frame")

    var body: some View {
        ZStack {
            stage
                .ignoresSafeArea()

            if let outcome = viewModel.outcome {
                ScanResultView(
                    photo: viewModel.capturedImage,
                    outcome: outcome,
                    onClose: { viewModel.retake() },
                    onPrimaryAction: { primaryAction(for: outcome) }
                )
            } else {
                cameraOverlay
            }
        }
        .task { await viewModel.startCamera() }
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }

    /// "Simpan" has nowhere to save to yet, so it just leaves the scanner.
    private func primaryAction(for outcome: ScanResultSheet.Outcome) {
        switch outcome {
        case .success:
            dismiss()
        case .needsProcessing, .multipleGarments:
            viewModel.retake()
        case .checking:
            break
        }
    }

    private var stage: some View {
        ZStack {
            if let image = viewModel.capturedImage {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                CameraPreview(session: viewModel.camera.session)
            }

            // Only until the shutter returns — after that the sheet does the waiting.
            if viewModel.phase == .analyzing, viewModel.capturedImage == nil {
                ProgressView().tint(.white).scaleEffect(1.4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var cameraOverlay: some View {
        VStack(spacing: 0) {
            topBar

            Spacer(minLength: 0)

            if viewModel.phase == .aiming {
                ClothingFrameOverlay(image: Self.clothingFrameImage)
            }

            Spacer(minLength: 0)

            bottomPanel
        }
    }

    private var topBar: some View {
        HStack {
            CircleIconButton(systemImage: "chevron.left") { dismiss() }
            Spacer()
            CircleIconButton(systemImage: viewModel.isTorchOn ? "bolt.fill" : "bolt.slash.fill") {
                viewModel.toggleTorch()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var bottomPanel: some View {
        VStack(spacing: 16) {
            ScanHintView(viewModel: viewModel)
            ScanControlsView(viewModel: viewModel)
        }
        .padding(.top, 20)
        .padding(.bottom, 28)
        .background(
            LinearGradient(
                colors: [.black.opacity(0), .black.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
}

#Preview { ScanView() }
