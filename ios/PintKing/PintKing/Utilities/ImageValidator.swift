//
//  ImageValidator.swift
//  PintKing
//
//  Client-side image validation run before an upload (avatar or pint photo).
//  Mirrors the API's server-side check (ImageValidation.kt): the file must be
//  a JPEG or PNG — detected by magic bytes, not a declared MIME type — and must
//  not exceed the per-asset size limit. This check exists for UX (fail fast
//  with an inline error); the server re-validates independently for security
//  (l3-ios-app.md §"Client-Side File Validation").
//

import Foundation

/// The two kinds of image the app uploads, each with its own size cap
/// (requirements §2.3 avatar 5 MB, §4.7 pint photo 10 MB).
enum ImageAsset {
    case avatar
    case pintPhoto

    /// Maximum allowed size in bytes. `5 * 1024 * 1024` / `10 * 1024 * 1024`
    /// exactly matches the API constants (MAX_AVATAR_BYTES / MAX_PHOTO_BYTES).
    var maxBytes: Int {
        switch self {
        case .avatar: return 5 * 1024 * 1024
        case .pintPhoto: return 10 * 1024 * 1024
        }
    }
}

/// Why validation failed. `tooLarge` carries the limit so the UI can name it.
enum ImageValidationError: Error, Equatable, Sendable {
    case tooLarge(maxBytes: Int)
    case unsupportedType
}

enum ImageValidator {

    /// Validates `data` for the given asset. Size is checked before format,
    /// matching the API's order. Returns normally when the file is a JPEG/PNG
    /// within the limit, otherwise throws a typed `ImageValidationError`.
    static func validate(_ data: Data, as asset: ImageAsset) throws {
        if data.count > asset.maxBytes {
            throw ImageValidationError.tooLarge(maxBytes: asset.maxBytes)
        }
        guard isJpeg(data) || isPng(data) else {
            throw ImageValidationError.unsupportedType
        }
    }

    // MARK: - Magic-byte detection (matches the API's ImageValidation)

    /// JPEG files start with the SOI marker `FF D8` followed by `FF`.
    private static func isJpeg(_ data: Data) -> Bool {
        data.count >= 3
            && data[data.startIndex] == 0xFF
            && data[data.startIndex + 1] == 0xD8
            && data[data.startIndex + 2] == 0xFF
    }

    /// PNG files start with the 8-byte signature `89 50 4E 47 0D 0A 1A 0A`.
    private static func isPng(_ data: Data) -> Bool {
        let signature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        guard data.count >= signature.count else { return false }
        return data.prefix(signature.count).elementsEqual(signature)
    }
}
