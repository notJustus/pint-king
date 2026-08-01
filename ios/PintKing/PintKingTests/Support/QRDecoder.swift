//
//  QRDecoder.swift
//  PintKingTests
//
//  Test-only counterpart to `QRCodeGenerator`: scans a rendered image back to the
//  string it encodes, so QR tests can assert a real round-trip rather than "an
//  image was produced". Uses CoreImage's own detector — the same job a phone
//  camera does at the other end of the invite flow.
//

import CoreImage
import UIKit

enum QRDecoder {

    /// The message encoded in `image`, or nil if no QR code could be read.
    static func decode(_ image: UIImage) -> String? {
        guard let ciImage = CIImage(image: image) else { return nil }

        let detector = CIDetector(
            ofType: CIDetectorTypeQRCode,
            context: nil,
            options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        )
        let features = detector?.features(in: ciImage) as? [CIQRCodeFeature]
        return features?.first?.messageString
    }
}
