//
//  QRCodeGenerator.swift
//  PintKing
//
//  Renders a string as a scannable QR code image (requirements §5.4: the invite
//  screen shows the Invite_Code, Invite_Link, and QR_Code).
//
//  A pure, stateless `enum` namespace like InitialsGenerator and ImageValidator —
//  no view, no view model, no hardware — so the generated image can be decoded
//  back in a unit test rather than eyeballed in the simulator.
//
//  CoreImage's generator emits a tiny image (one pixel per QR module), which
//  scales up blurry. It is scaled here with a plain affine transform *before*
//  rasterising, so the result is crisp at any display size.
//

import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

enum QRCodeGenerator {

    /// A QR code encoding `string`, or nil if the string is empty or CoreImage
    /// fails to produce an image.
    ///
    /// - Parameter scale: pixels per QR module. The default renders an invite
    ///   link at roughly 300–400 pt, comfortably scannable across a table.
    static func image(for string: String, scale: CGFloat = 12) -> UIImage? {
        guard !string.isEmpty else { return nil }

        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        // Medium error correction: ~15% of the code can be obscured (a thumb, a
        // glare) and still scan, without inflating the module count.
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else { return nil }

        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        // A fresh context per call: this runs a handful of times per screen (once
        // per code), so caching one in a `static let` would only buy a Swift 6
        // Sendable problem for no measurable gain.
        guard let cgImage = CIContext().createCGImage(scaled, from: scaled.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
