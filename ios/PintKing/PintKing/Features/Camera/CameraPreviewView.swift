//
//  CameraPreviewView.swift
//  PintKing
//
//  Bridges the AVCaptureVideoPreviewLayer into SwiftUI. There's no SwiftUI-native
//  camera preview, so we host a plain UIView whose backing layer *is* the preview
//  layer (via `layerClass`), and hand it the running session. This is device-only
//  code — the simulator has no camera — so it isn't unit-tested.
//

import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        // Keep the layer's session in sync if the model ever swaps it.
        uiView.previewLayer.session = session
    }

    /// A UIView whose backing layer is the preview layer, so it resizes with the
    /// view automatically (no manual frame bookkeeping).
    final class PreviewUIView: UIView {
        override static var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
