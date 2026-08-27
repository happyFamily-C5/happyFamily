//
//  ScanView.swift
//  happyFamily
//
//  Created by Calzy Akmal Indyramdhani on 26/08/26.
//

import PhotosUI
import SwiftUI

struct ScanView: View {
    @StateObject private var viewModel = ScanViewModel()
    @Environment(\.dismiss) private var dismiss

    private static let clothingFrameImage = UIImage.bundled("clothing_frame")

    var body: some View {
        ZStack {
            stage
                .ignoresSafeArea()

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
        .task { await viewModel.startCamera() }
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }

    private var stage: some View {
        ZStack {
            switch viewModel.phase {
            case .aiming:
                CameraPreview(session: viewModel.camera.session)
            case .analyzing, .reviewing, .rejected:
                if let image = viewModel.capturedImage {
                    Image(uiImage: image).resizable().scaledToFill()
                }
            }
            if viewModel.phase == .analyzing {
                ProgressView().tint(.white).scaleEffect(1.4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var topBar: some View {
        HStack {
            CircleIconButton(systemImage: "chevron.left") { dismiss() }
            Spacer()
            if viewModel.phase == .aiming || viewModel.phase == .analyzing {
                CircleIconButton(systemImage: viewModel.isTorchOn ? "bolt.fill" : "bolt.slash.fill") {
                    viewModel.toggleTorch()
                }
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
