//
//  PhotoProcessor.swift
//  PintKing
//
//  The camera's photo-processing pipeline, factored out of `CameraModel` so it
//  can be unit-tested with no capture hardware. Given the raw bytes a capture
//  hands us (HEIC on a real iPhone, or JPEG/PNG anywhere), it produces JPEG bytes
//  that fit the size cap — matching the design's pipeline (l3-ios-app.md §5):
//
//    1. Decode the input to a CGImage (fails fast if it isn't an image).
//    2. Re-encode as JPEG, walking a quality ladder from best to worst.
//    3. Return the first result that fits `maxBytes`; if even the lowest quality
//       overshoots, throw so the caller can show an error and stay on the camera.
//
//  We always re-encode to JPEG rather than passing a small input through
//  untouched: it collapses "convert HEIC→JPEG" and "compress if too large" into
//  one step, and the server only stores JPEG/PNG anyway (ImageValidation.kt).
//

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// Why the pipeline gave up. `tooLargeAfterCompression` carries the cap so the UI
/// can name it; `decodeFailed` means the bytes weren't a decodable image.
enum PhotoProcessingError: Error, Equatable, Sendable {
    case decodeFailed
    case tooLargeAfterCompression(maxBytes: Int)
}

enum PhotoProcessor {

    /// JPEG quality steps tried in order, best first. The capture is already a
    /// full-quality photo, so we start high and only drop quality when the byte
    /// budget forces it — the lowest rung (0.3) still looks acceptable for a
    /// social pint photo while shedding a lot of size.
    private static let qualityLadder: [Double] = [0.9, 0.7, 0.5, 0.3]

    /// Re-encode `data` to a JPEG no larger than `maxBytes`. Defaults to the
    /// 10 MB pint-photo cap (shared with `ImageValidator`, so the client's
    /// pre-upload check and the API agree). Throws `PhotoProcessingError`.
    static func process(
        _ data: Data,
        maxBytes: Int = ImageAsset.pintPhoto.maxBytes
    ) throws -> Data {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw PhotoProcessingError.decodeFailed
        }

        // Walk the ladder; the first encoding that fits wins.
        for quality in qualityLadder {
            guard let jpeg = encodeJpeg(image, quality: quality) else { continue }
            if jpeg.count <= maxBytes {
                return jpeg
            }
        }

        // Even the lowest quality overshoots — nothing more we can shed.
        throw PhotoProcessingError.tooLargeAfterCompression(maxBytes: maxBytes)
    }

    /// Encodes `image` to JPEG at the given lossy quality via `ImageIO`. Returns
    /// nil only if the destination can't be created or finalised (unexpected).
    private static func encodeJpeg(_ image: CGImage, quality: Double) -> Data? {
        let out = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            out, UTType.jpeg.identifier as CFString, 1, nil
        ) else { return nil }
        let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return out as Data
    }
}
