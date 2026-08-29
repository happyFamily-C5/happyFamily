//
//  CameraScanView.swift
//  Recap
//
//  Created by binc876 on 29/08/26.
//

import PhotosUI
import SwiftUI
import UIKit

struct CameraScanView: View {

    @Environment(\.dismiss)
    private var dismiss

    @State private var viewModel =
        CameraScanViewModel()

    @State private var selectedPhotoItem: PhotosPickerItem?

    private let onImageConfirmed: (UIImage, ClothingAnalysis) -> Void

    init(
        onImageConfirmed: @escaping (UIImage, ClothingAnalysis) -> Void = { _, _ in }
    ) {
        self.onImageConfirmed = onImageConfirmed
    }

    var body: some View {

        ZStack {

            backgroundContent
                .ignoresSafeArea()

            cameraOverlay
        }
        .navigationBarBackButtonHidden(true)

        .onAppear {
            viewModel.startCamera()
        }

        .onDisappear {
            viewModel.stopCamera()
        }

        .onChange(of: selectedPhotoItem) { _, newItem in

            guard let newItem else {
                return
            }

            Task {

                defer {
                    selectedPhotoItem = nil
                }

                if let data = try? await newItem.loadTransferable(
                    type: Data.self
                ),
                   let image = UIImage(data: data) {

                    viewModel.selectPhoto(image)
                }
            }
        }

        .sheet(
            isPresented:
                $viewModel.showResultSheet
            ,
            onDismiss: {
                viewModel.retry()
            }
        ) {

            ScanResultSheet(
                state:
                    viewModel.analysisState,
                analysis:
                    viewModel.analysisResult,
                image:
                    viewModel.capturedImage,
                showsActions: true,
                onAddImage: {
                    if let image = viewModel.capturedImage,
                       let analysis = viewModel.analysisResult {

                        onImageConfirmed(image, analysis)
                        viewModel.retry()
                        dismiss()
                    }
                },
                onScanAgain: {
                    viewModel.retry()
                }
            )
            .presentationDetents(
                [.medium]
            )
            .presentationDragIndicator(
                .visible
            )
        }
    }
}

private extension CameraScanView {

    @ViewBuilder
    var backgroundContent: some View {

        if let capturedImage = viewModel.capturedImage {
            Image(uiImage: capturedImage)
                .resizable()
                .scaledToFill()
                .overlay(
                    Color.black.opacity(0.12)
                )
        } else {
            CameraPreview(
                session:
                    viewModel.cameraManager.session
            )
        }
    }
}

private extension CameraScanView {

    var cameraOverlay: some View {

        VStack {

            topControls

            Spacer()

            clothingFrame

            Spacer()

            bottomControls
        }
    }
}

private extension CameraScanView {
    var topControls: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                .font(
                    .system(
                        size: 20,
                        weight: .medium
                    )
                )
                .foregroundStyle(.white)
                .frame(
                    width: 40,
                    height: 40
                )
                .background(
                    Circle()
                        .fill(
                            .black.opacity(0.45)
                        )
                )
            }

            Spacer()

            Button {
                // Flash action
                // nanti kita implement

            } label: {
                Image(systemName: "bolt.slash.fill")
                .font(.system(size: 17))
                .foregroundStyle(.white)
                .frame(
                    width: 40,
                    height: 40
                )
                .background(
                    Circle()
                        .fill(
                            .black.opacity(0.45)
                        )
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

private extension CameraScanView {
    var clothingFrame: some View {
        RoundedRectangle(
            cornerRadius: 30
        )
        .stroke(
            .white,
            style: StrokeStyle(
                lineWidth: 4,
                dash: [12, 8]
            )
        )
        .frame(
            width: 310,
            height: 400
        )
    }
}

private extension CameraScanView {
    var bottomControls: some View {
        VStack(spacing: 20) {

            instruction

            HStack {

                photoLibraryButton

                Spacer()

                shutterButton

                Spacer()

                switchCameraButton
            }
            .padding(.horizontal, 45)
            .padding(.bottom, 25)
        }
    }

    var instruction: some View {
        HStack(spacing: 10) {
            Image(
                systemName: "info.circle.fill"
            )
            .font(.system(size: 22))

            Text(
                "Bentangkan satu pakaian dalam bingkai."
            )
            .font(.system(size: 12))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .frame(
            height: 72
        )
        .background(
            RoundedRectangle(
                cornerRadius: 22
            )
            .fill(
                .black.opacity(0.65)
            )
        )
        .padding(.horizontal, 30)
    }
}

private extension CameraScanView {
    var shutterButton: some View {
        Button {
            viewModel.capturePhoto()
        } label: {
            Circle()
                .fill(.white)
                .frame(
                    width: 72,
                    height: 72
                )
                .overlay {

                    Circle()
                        .stroke(
                            .white,
                            lineWidth: 3
                        )
                        .padding(5)
                }
        }
    }
}

private extension CameraScanView {
    var photoLibraryButton: some View {
        PhotosPicker(
            selection: $selectedPhotoItem,
            matching: .images
        ) {
            ZStack {
                RoundedRectangle(
                    cornerRadius: 12
                )
                .fill(.white)

                Image(
                    systemName: "photo"
                )
                .font(.system(size: 22))
                .foregroundStyle(.gray)
            }
            .frame(
                width: 58,
                height: 58
            )
        }
    }
}

private extension CameraScanView {
    var switchCameraButton: some View {
        Button {
            // nanti switch front/back camera

        } label: {
            Image(
                systemName:
                    "arrow.triangle.2.circlepath.camera"
            )
            .font(.system(size: 20))
            .foregroundStyle(.white)
            .frame(
                width: 48,
                height: 48
            )
            .background(
                Circle()
                    .fill(
                        .black.opacity(0.45)
                    )
            )
        }
    }
}

#Preview {
    CameraScanView()
}
