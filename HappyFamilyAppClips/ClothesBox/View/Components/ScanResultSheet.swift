//
//  ScanResultSheet.swift
//  Recap
//
//  Created by binc876 on 29/08/26.
//

import SwiftUI
import UIKit

struct ScanResultSheet: View {

    let state: CameraScanViewModel.AnalysisState
    let analysis: ClothingAnalysis?
    let image: UIImage?
    let showsActions: Bool
    let onAddImage: () -> Void
    let onScanAgain: () -> Void

    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(
                    Color.gray.opacity(0.4)
                )
                .frame(
                    width: 36,
                    height: 4
                )
                .padding(.top, 8)

            Text("Hasil Scan")
                .font(
                    .system(
                        size: 16,
                        weight: .semibold
                    )
                )
                .padding(.top, 12)

            Spacer()

            if let image, !showsActions {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .padding(.bottom, 20)
            }

            switch state {

            case .idle:
                EmptyView()

            case .analyzing:
                checkingView

            case .completed:

                if let analysis {
                    resultView(analysis)
                }

            case .failed:
                failedView
            }

            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private var checkingView: some View {

        HStack(spacing: 10) {

            ProgressView()

            Text("Checking the result...")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
        }
    }

    private var failedView: some View {
        VStack(spacing: 14) {
            ErrorIcon()
                .padding(.bottom, 8)

            Text("Gagal menganalisis gambar.")
                .font(.system(size: 18, weight: .semibold))

            Text("Coba ambil foto ulang dengan objek yang lebih jelas dan pencahayaan cukup.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if showsActions {
                ButtonSheet("Foto Ulang", color: .red) {
                    onScanAgain()
                    dismiss()
                }
            }
        }
    }

    @ViewBuilder
    private func resultView(_ analysis: ClothingAnalysis) -> some View {
        switch analysis.scanOutcome {
        case .needsProcessing:
            needsProcessingView(accessories: analysis.detectedAccessories)

        case .success:
            successView(analysis)

        case .multipleDetected:
            multipleDetectedView
        }
    }

    //masih ada aksesoris
    private func needsProcessingView(accessories: [String]) -> some View {
        VStack(spacing: 14) {
            ErrorIcon()

            VStack {
                Text("Pakaian Butuh Diproses Lagi")
                    .font(.title2.bold())
                    .foregroundStyle(AppColor.textDarkCyan)
                    .multilineTextAlignment(.center)
                
                VStack(spacing: 16) {
                    Text("Lepaskan aksesoris berikut:")
                        .font(.body)
                        .foregroundStyle(AppColor.textDarkCyan)
                        .multilineTextAlignment(.center)
                    
                    AccessoriesRow(accessories)
                }
                .padding(.top, 32)
            }
            .padding(.top, 8)
            .padding(.bottom, 32)

            if showsActions {
                ButtonSheet("Foto Ulang", color: .red) {
                    onScanAgain()
                    dismiss()
                }
            }
        }
        .padding(.top, 12)
    }

    //berhasil
    private func successView(_ analysis: ClothingAnalysis) -> some View {
        VStack(spacing: 14) {
            SuccessIcon()

            VStack(spacing: 8) {
                Text("Berhasil!")
                    .font(.title.bold())
                    .foregroundStyle(AppColor.textDarkCyan)
                    .multilineTextAlignment(.center)
                
                Text("Pakaian sudah sesuai dan memenuhi kriteria untuk didonasikan.")
                    .font(.body)
                    .foregroundStyle(AppColor.textDarkCyan)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)
            .padding(.bottom, 32)

            if showsActions {
                ButtonSheet("Simpan", color: AppColor.primaryCyan) {
                    onAddImage()
                }
            }
        }
        .padding(.top, 12)
    }

    //lebih dari satu pakaian
    private var multipleDetectedView: some View {
        VStack(spacing: 14) {
            ErrorIcon()

            VStack(spacing: 8) {
                Text("Terdeteksi Lebih Dari Satu Pakaian")
                    .font(.title2.bold())
                    .foregroundStyle(AppColor.textDarkCyan)
                    .multilineTextAlignment(.center)
                
                Text("Scan hanya bisa untuk satu pakaian dalam satu foto.")
                    .font(.body)
                    .foregroundStyle(AppColor.textDarkCyan)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)
            .padding(.bottom, 32)

            if showsActions {
                ButtonSheet("Foto Ulang", color: .red) {
                    onScanAgain()
                    dismiss()
                }
            }
        }
        .padding(.top, 12)
    }
}

#Preview("Success") {
    ScanResultSheet(
        state: .completed,
        analysis: ClothingAnalysis(
            detectedAccessories: [],
            hasMultipleItems: false
        ),
        image: nil,
        showsActions: true,
        onAddImage: {},
        onScanAgain: {}
    )
}
