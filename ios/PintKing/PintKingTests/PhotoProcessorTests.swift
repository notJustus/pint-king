//
//  PhotoProcessorTests.swift
//  PintKingTests
//
//  Task 11: the camera's photo-processing pipeline — the one piece of the
//  camera stack that has no hardware dependency and so can be unit-tested. The
//  AVCaptureSession itself (rear-camera input, live preview, real capture) needs
//  a device and is exercised on-device, not here (l3-ios-app.md §5).
//
//  `PhotoProcessor.process(_:maxBytes:)` mirrors the design's pipeline: whatever
//  the capture hands us (HEIC on a real iPhone) is re-encoded to JPEG, then
//  compressed down a quality ladder until it fits the size cap — erroring only
//  if it's still too large at the lowest quality. `maxBytes` is injectable so the
//  "still too large after compression" path is deterministic without a giant
//  image; production callers use the 10 MB `ImageAsset.pintPhoto` default.
//

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Testing
@testable import PintKing

struct PhotoProcessorTests {

    // MARK: - Fixtures

    /// A `width`×`height` RGB image filled with a diagonal colour gradient, so
    /// the encoded JPEG carries real detail (a flat fill would compress to almost
    /// nothing and make the size assertions meaningless).
    private func makeImage(width: Int, height: Int) -> CGImage {
        let space = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        let gradient = CGGradient(
            colorsSpace: space,
            colors: [
                CGColor(red: 1, green: 0, blue: 0, alpha: 1),
                CGColor(red: 0, green: 1, blue: 0, alpha: 1),
                CGColor(red: 0, green: 0, blue: 1, alpha: 1),
            ] as CFArray,
            locations: [0, 0.5, 1]
        )!
        context.drawLinearGradient(
            gradient,
            start: .zero,
            end: CGPoint(x: width, y: height),
            options: []
        )
        return context.makeImage()!
    }

    /// Encodes `image` to `type` (optionally at a fixed lossy quality), returning
    /// the container bytes — used to build JPEG/PNG/HEIC inputs for the processor.
    private func encode(_ image: CGImage, as type: UTType, quality: Double? = nil) -> Data? {
        let out = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            out, type.identifier as CFString, 1, nil
        ) else { return nil }
        var options: [CFString: Any] = [:]
        if let quality { options[kCGImageDestinationLossyCompressionQuality] = quality }
        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return out as Data
    }

    private func isJpeg(_ data: Data) -> Bool {
        data.count >= 3 && data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF
    }

    // MARK: - Format conversion

    @Test func reEncodesPngInputToJpeg() throws {
        let png = try #require(encode(makeImage(width: 64, height: 64), as: .png))
        // Sanity: the input really is a PNG, not already a JPEG.
        #expect(!isJpeg(png))

        let output = try PhotoProcessor.process(png)
        #expect(isJpeg(output))
    }

    @Test func convertsHeicInputToJpeg() throws {
        // HEIC is what a real iPhone capture produces; the processor must turn it
        // into JPEG. (Skips cleanly if this platform can't encode HEIC.)
        guard let heic = encode(makeImage(width: 64, height: 64), as: .heic) else { return }
        #expect(!isJpeg(heic))

        let output = try PhotoProcessor.process(heic)
        #expect(isJpeg(output))
    }

    // MARK: - Size handling

    @Test func underLimitReturnsJpegUnchangedInSize() throws {
        let jpeg = try #require(encode(makeImage(width: 64, height: 64), as: .jpeg))
        // A tiny image is comfortably under the 10 MB default cap.
        let output = try PhotoProcessor.process(jpeg)
        #expect(isJpeg(output))
        #expect(output.count <= ImageAsset.pintPhoto.maxBytes)
    }

    @Test func compressesFurtherWhenTopQualityExceedsLimit() throws {
        let source = try #require(encode(makeImage(width: 512, height: 512), as: .png))

        // Baseline: what the processor produces at its best quality (huge cap).
        let baseline = try PhotoProcessor.process(source, maxBytes: .max)

        // Ask for a cap one byte under that baseline: top quality no longer fits,
        // so the processor must step down the quality ladder and hand back
        // something strictly smaller — proving compression actually kicked in.
        let compressed = try PhotoProcessor.process(source, maxBytes: baseline.count - 1)
        #expect(isJpeg(compressed))
        #expect(compressed.count < baseline.count)
    }

    @Test func throwsWhenStillTooLargeAfterCompression() throws {
        let source = try #require(encode(makeImage(width: 128, height: 128), as: .png))
        // No JPEG of a real image fits in 16 bytes, so even the lowest quality on
        // the ladder overshoots — the processor gives up with a typed error.
        #expect(throws: PhotoProcessingError.tooLargeAfterCompression(maxBytes: 16)) {
            try PhotoProcessor.process(source, maxBytes: 16)
        }
    }

    @Test func throwsWhenDataIsNotAnImage() {
        let garbage = Data([0x00, 0x01, 0x02, 0x03, 0x04, 0x05])
        #expect(throws: PhotoProcessingError.decodeFailed) {
            try PhotoProcessor.process(garbage)
        }
    }
}
