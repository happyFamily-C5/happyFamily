//
//  ClothesBoxView.swift
//  Recap
//
//  Created by binc876 on 29/08/26.
//

import SwiftUI
import UIKit

struct ClothesBoxView: View {
    @State private var viewModel = ClothesBoxViewModel()

    var body: some View {
        VStack(spacing: 0) {

            header

            content

            Spacer()

            if !viewModel.items.isEmpty {
                continueButton
            }
        }
        .fullScreenCover(
            isPresented:
                $viewModel.showCamera
        ) {
            CameraScanView { image, analysis in
                viewModel.addImage(
                    image,
                    analysis: analysis
                )
            }
        }
        .sheet(
            isPresented:
                $viewModel.showPreview
        ) {
            if let item = viewModel.previewItem {
                ScanResultSheet(
                    state: .completed,
                    analysis: item.analysis,
                    image: item.image,
                    showsActions: false,
                    onAddImage: {},
                    onScanAgain: {}
                )
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

private extension ClothesBoxView {
    var header: some View {
        VStack(spacing: 16) {
            HStack {
                Button {
                    // back
                } label: {
                    Image(systemName: "chevron.left")
                    .font(.system(size: 19,weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40
                    )
                }

                Spacer()

                Text("Step 2 of 3")
                    .font(.system(size: 14,weight: .semibold))
            }

            progressBar
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    var progressBar: some View {

        HStack(spacing: 5) {

            Capsule()
                .fill(AppColor.primaryCyan)

            Capsule()
                .fill(AppColor.primaryCyan)

            Capsule()
                .fill(AppColor.primaryCyan)
        }
        .frame(height: 7)
    }
}

private extension ClothesBoxView {
    // Kalau belum ada item yang di-scan -> tampilkan instruksi awal + tombol "Ambil gambar".
    // Begitu ada item -> instruksi hilang total, langsung ke grid hasil scan
    // (tombol tambah foto sudah jadi bagian dari grid itu sendiri).
    var content: some View {
        VStack(spacing: 0) {
            if viewModel.items.isEmpty {
                Image("Thumbnail-Clothes")
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: 300,
                        height: 270
                    )

                VStack {
                    Text("Ambil Gambar Baju Anda!")
                        .font(.title3.bold())
                        .padding(.top, 8)

                    Text("Daftarkan semua baju yang akan Anda donasikan! Pastikan memenuhi kriteria berikut: berbahan katun minimal 70% dan sudah dilepas dari semua aksesori.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 16)

                startCameraButton
            } else {
                ScanResultView(
                    count: viewModel.items.count,
                    imageAtIndex: { index in
                        viewModel.items[index].image
                    },
                    onPreview: { index in
                        viewModel.openPreview(
                            for: viewModel.items[index]
                        )
                    },
                    onAdd: {
                        viewModel.openCamera()
                    }
                )
            }
        }
        .padding(.top, viewModel.items.isEmpty ? 120 : 24)
        .animation(.easeInOut, value: viewModel.items.isEmpty)
    }
}

private extension ClothesBoxView {
    var startCameraButton: some View {
        Button {
            viewModel.openCamera()
        } label: {
            Text("Ambil gambar")
                .font(.body.bold())
                .foregroundStyle(.white)
                .frame(
                    width: 220,
                    height: 52
                )
                .background(
                    AppColor.primaryCyan
                )
                .clipShape(
                    Capsule()
                )
        }
        .buttonStyle(.plain)
        .padding(.top, 24)
    }
}

private extension ClothesBoxView {
    var continueButton: some View {
        Button {
            //next ke ShippingMethod
        } label: {
            Text("Lanjut")
                .font(.body.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(AppColor.primaryCyan)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
}

#Preview {
    ClothesBoxView()
}
