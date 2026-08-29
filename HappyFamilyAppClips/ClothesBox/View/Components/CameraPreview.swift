//
//  CameraPreview.swift
//  Recap
//
//  Created by binc876 on 29/08/26.
//

import SwiftUI
import AVFoundation

struct CameraPreview: UIViewRepresentable {

    let session: AVCaptureSession

    func makeUIView(
        context: Context
    ) -> PreviewView {

        let view = PreviewView()

        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill

        return view
    }

    func updateUIView(
        _ uiView: PreviewView,
        context: Context
    ) {

        uiView.videoPreviewLayer.session = session
    }
}

final class PreviewView: UIView {

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer:
        AVCaptureVideoPreviewLayer {

        layer as! AVCaptureVideoPreviewLayer
    }
}

#Preview {
    CameraPreview(
        session: AVCaptureSession()
    )
}
