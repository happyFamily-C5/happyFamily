//
//  ScanControlsView.swift
//  happyFamily
//
//  Created by Calzy Akmal Indyramdhani on 26/08/26.
//

import PhotosUI
import SwiftUI

struct ScanControlsView: View {
    @ObservedObject var viewModel: ScanViewModel

    var body: some View {
        HStack {
            switch viewModel.phase {
            case .aiming, .analyzing:
                PhotosPicker(selection: $viewModel.pickedItem, matching: .images) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
                }

                Spacer()

                Button {
                    Task { await viewModel.capture() }
                } label: {
                    Circle().strokeBorder(.white, lineWidth: 4)
                        .frame(width: 72, height: 72)
                        .overlay(Circle().fill(.white).frame(width: 58, height: 58))
                }
                .disabled(viewModel.phase == .analyzing)

                Spacer()

                CircleIconButton(systemImage: "arrow.trianglehead.2.clockwise.rotate.90") {
                    viewModel.flipCamera()
                }
            case .reviewing, .rejected:
                Button("Scan Lagi") { viewModel.retake() }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 32)
    }
}
