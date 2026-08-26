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

    private static let palette: [String: Color] = [
        "resleting": .cyan, "saku": .yellow, "ornamen/logam": .orange,
    ]

    var body: some View {
        VStack(spacing: 0) {
            stage
                .frame(maxWidth: .infinity)
                .frame(height: 420)
                .clipped()
                .background(Color.black)

            controls
                .padding(.vertical, 12)

            ScrollView { results.padding(.horizontal) }
        }
        .task { await viewModel.startCamera() }
    }

    private var stage: some View {
        ZStack {
            switch viewModel.phase {
            case .aiming:
                CameraPreview(session: viewModel.camera.session)
            case .analyzing, .reviewing, .rejected:
                if let image = viewModel.capturedImage {
                    Image(uiImage: image).resizable().scaledToFit()
                }
            }
            if viewModel.phase == .analyzing {
                ProgressView().tint(.white).scaleEffect(1.4)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 16) {
            switch viewModel.phase {
            case .aiming, .analyzing:
                PhotosPicker(selection: $viewModel.pickedItem, matching: .images) {
                    Label("Galeri", systemImage: "photo").labelStyle(.iconOnly).font(.title2)
                }
                Button {
                    Task { await viewModel.capture() }
                } label: {
                    Circle().strokeBorder(.primary, lineWidth: 4)
                        .frame(width: 66, height: 66)
                        .overlay(Circle().fill(.primary).frame(width: 52, height: 52))
                }
                .disabled(viewModel.phase == .analyzing)
            case .reviewing, .rejected:
                Button("Scan Lagi") { viewModel.retake() }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private var results: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let status = viewModel.statusMessage {
                Text(status).font(.footnote).foregroundStyle(.orange)
            }

            switch viewModel.phase {
            case .aiming:
                Text("Arahkan ke satu helai pakaian, lalu tekan tombol foto.")
                    .foregroundStyle(.secondary)
            case .analyzing:
                Text("Menganalisis…").foregroundStyle(.secondary)
            case .rejected:
                Text("TERDETEKSI LEBIH DARI SATU PAKAIAN")
                    .font(.title3.bold()).foregroundStyle(.red)
                Text("Scan hanya bisa dilakukan untuk satu helai pakaian. "
                    + "Foto ulang dengan satu baju, celana, atau rok saja — "
                    + "pastikan memenuhi bingkai dan tidak ada pakaian lain ikut terlihat.")
                    .foregroundStyle(.secondary)
            case .reviewing:
                Text(viewModel.result.needsProcessing ? "PERLU DIPROSES" : "AMAN")
                    .font(.title2.bold())
                    .foregroundStyle(viewModel.result.needsProcessing ? .orange : .green)

                if let type = viewModel.result.garmentType {
                    Text("\(type.name) · \(String(format: "%.0f%%", type.confidence * 100))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ForEach(Array(viewModel.result.grouped.enumerated()), id: \.offset) { _, row in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Circle().fill(Self.palette[row.label] ?? .gray)
                            .frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.label).fontWeight(.semibold)
                        }
                        Spacer()
                        Text(String(format: "%.0f%%", row.confidence * 100))
                            .monospacedDigit()
                    }
                }

                if viewModel.result.present.isEmpty {
                    Text("Tidak ada aksesoris terdeteksi.").foregroundStyle(.secondary)
                }

                Text("Threshold masih dikalibrasi dari foto editorial, belum dari foto HP.")
                    .font(.caption2).foregroundStyle(.secondary).padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview { ScanView() }
