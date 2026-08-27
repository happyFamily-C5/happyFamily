//
//  CameraPreview.swift
//  happyFamily
//
//  Created by Calzy Akmal Indyramdhani on 26/08/26.
//

import AVFoundation
import SwiftUI

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        // UIKit requires `layerClass` to be a class var — `static` cannot be overridden.
        // swiftlint:disable:next static_over_final_class
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        // Guaranteed by `layerClass` above.
        // swiftlint:disable force_cast
        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
        // swiftlint:enable force_cast
    }
}
