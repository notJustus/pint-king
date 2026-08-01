//
//  UtilitiesTests.swift
//  PintKingTests
//
//  Task 4: the two pure utility helpers.
//
//  `InitialsGenerator` pins design Property 7: for any non-empty display name
//  the initials contain the first character of the first word and the first
//  character of the last word (or just the first for a single word) and are
//  never empty. `ImageValidator` mirrors the API's server-side check
//  (ImageValidation.kt): JPEG/PNG by magic bytes, size ≤ the per-asset limit.
//

import Foundation
import Testing
import UIKit
@testable import PintKing

// MARK: - InitialsGenerator

struct InitialsGeneratorTests {

    @Test func singleWordUsesFirstCharacter() {
        #expect(InitialsGenerator.initials(from: "Dave") == "D")
    }

    @Test func twoWordsUseFirstAndLastInitials() {
        #expect(InitialsGenerator.initials(from: "Dave Smith") == "DS")
    }

    @Test func multipleWordsUseFirstAndLastOnly() {
        // First char of first word + first char of *last* word — the middle
        // word ("van") is ignored.
        #expect(InitialsGenerator.initials(from: "Dave van Smith") == "DS")
    }

    @Test func resultIsUppercased() {
        #expect(InitialsGenerator.initials(from: "dave smith") == "DS")
    }

    @Test func extraWhitespaceIsIgnored() {
        #expect(InitialsGenerator.initials(from: "  Dave   Smith  ") == "DS")
    }

    @Test func emptyStringFallsBackToPlaceholder() {
        #expect(InitialsGenerator.initials(from: "") == "?")
    }

    @Test func whitespaceOnlyFallsBackToPlaceholder() {
        #expect(InitialsGenerator.initials(from: "   ") == "?")
    }

    @Test func unicodeGraphemeClusterIsTreatedAsOneCharacter() {
        // A flag emoji is a single grapheme cluster made of multiple scalars;
        // taking `.first` must keep it whole rather than slicing a scalar.
        #expect(InitialsGenerator.initials(from: "🇬🇧 Pub") == "🇬🇧P")
    }

    @Test func accentedCharactersArePreserved() {
        #expect(InitialsGenerator.initials(from: "Ástþór Ómar") == "ÁÓ")
    }
}

// MARK: - ImageValidator

struct ImageValidatorTests {

    // Magic-byte prefixes, matching the API's ImageValidation.kt.
    private static let jpegMagic: [UInt8] = [0xFF, 0xD8, 0xFF]
    private static let pngMagic: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

    /// Builds `Data` of exactly `size` bytes that begins with `magic` (padded
    /// with zeros). `size` must be ≥ the magic prefix length.
    private func makeImage(magic: [UInt8], size: Int) -> Data {
        var bytes = magic
        bytes.append(contentsOf: Array(repeating: 0, count: size - magic.count))
        return Data(bytes)
    }

    @Test func jpegUnderLimitPasses() throws {
        let data = makeImage(magic: Self.jpegMagic, size: 1_000)
        try ImageValidator.validate(data, as: .avatar)
    }

    @Test func pngUnderLimitPasses() throws {
        let data = makeImage(magic: Self.pngMagic, size: 1_000)
        try ImageValidator.validate(data, as: .pintPhoto)
    }

    @Test func avatarExactlyAtFiveMegabytesPasses() throws {
        let data = makeImage(magic: Self.jpegMagic, size: ImageAsset.avatar.maxBytes)
        try ImageValidator.validate(data, as: .avatar)
    }

    @Test func pintPhotoExactlyAtTenMegabytesPasses() throws {
        let data = makeImage(magic: Self.jpegMagic, size: ImageAsset.pintPhoto.maxBytes)
        try ImageValidator.validate(data, as: .pintPhoto)
    }

    @Test func avatarJustOverFiveMegabytesIsRejected() {
        let data = makeImage(magic: Self.jpegMagic, size: ImageAsset.avatar.maxBytes + 1)
        #expect(throws: ImageValidationError.tooLarge(maxBytes: ImageAsset.avatar.maxBytes)) {
            try ImageValidator.validate(data, as: .avatar)
        }
    }

    @Test func pintPhotoJustOverTenMegabytesIsRejected() {
        let data = makeImage(magic: Self.jpegMagic, size: ImageAsset.pintPhoto.maxBytes + 1)
        #expect(throws: ImageValidationError.tooLarge(maxBytes: ImageAsset.pintPhoto.maxBytes)) {
            try ImageValidator.validate(data, as: .pintPhoto)
        }
    }

    @Test func fiveMegabyteJpegExceedsAvatarLimitButFitsPintPhoto() throws {
        // The same bytes are valid as a pint photo yet too large as an avatar —
        // proves the limit is per-asset, not global.
        let data = makeImage(magic: Self.jpegMagic, size: ImageAsset.avatar.maxBytes + 1)
        try ImageValidator.validate(data, as: .pintPhoto)
    }

    @Test func wrongTypeIsRejected() {
        // A GIF header ("GIF8") is neither JPEG nor PNG.
        let data = Data([0x47, 0x49, 0x46, 0x38, 0x00, 0x00])
        #expect(throws: ImageValidationError.unsupportedType) {
            try ImageValidator.validate(data, as: .avatar)
        }
    }

    @Test func emptyDataIsRejectedAsUnsupportedType() {
        #expect(throws: ImageValidationError.unsupportedType) {
            try ImageValidator.validate(Data(), as: .avatar)
        }
    }

    @Test func oversizeCheckTakesPrecedenceOverType() {
        // Mirrors the API's order (size checked before format): an over-limit
        // file of the wrong type reports `.tooLarge`, not `.unsupportedType`.
        let bytes = [UInt8](repeating: 0, count: ImageAsset.avatar.maxBytes + 1)
        #expect(throws: ImageValidationError.tooLarge(maxBytes: ImageAsset.avatar.maxBytes)) {
            try ImageValidator.validate(Data(bytes), as: .avatar)
        }
    }
}

// MARK: - InviteLink

/// Task 23: the invite link format. One namespace owns it because two features
/// sit on opposite ends — the Invite screen builds links, the deep-link handler
/// (Task 28) parses them.
struct InviteLinkTests {

    @Test func linkIsHttpsHostAndJoinPath() {
        #expect(
            InviteLink.url(for: "aB3dE6fH").absoluteString
                == "https://pintking.app/join/aB3dE6fH"
        )
    }

    @Test func codeCasingIsPreserved() {
        // Invite codes are case-sensitive on the server, so the link must not
        // normalise them.
        #expect(InviteLink.url(for: "abcd1234") != InviteLink.url(for: "ABCD1234"))
    }

    @Test func componentsMatchWhatTheDeepLinkHandlerWillParse() {
        let url = InviteLink.url(for: "kM9nP2qR")
        #expect(url.scheme == "https")
        #expect(url.host() == InviteLink.host)
        #expect(url.pathComponents == ["/", InviteLink.pathPrefix, "kM9nP2qR"])
    }

    // MARK: - Parsing (Task 28)

    @Test(arguments: ["aB3dE6fH", "ABCD1234", "abcd1234", "00000000"])
    func buildingThenParsingReturnsTheSameCode(code: String) {
        // The round trip is the point of keeping both directions in one type,
        // and casing must survive it — the server's alphabet is mixed-case and
        // its lookup is exact.
        #expect(InviteLink.code(from: InviteLink.url(for: code)) == code)
    }

    @Test func queryItemsOnASharedLinkAreIgnored() {
        let url = URL(string: "https://pintking.app/join/aB3dE6fH?utm_source=whatsapp")!
        #expect(InviteLink.code(from: url) == "aB3dE6fH")
    }

    @Test func schemeAndHostAreMatchedCaseInsensitively() {
        // Both are case-insensitive per RFC 3986, and a link retyped by hand or
        // mangled by a share sheet may arrive capitalised.
        let url = URL(string: "HTTPS://PintKing.App/join/aB3dE6fH")!
        #expect(InviteLink.code(from: url) == "aB3dE6fH")
    }

    @Test func trailingSlashIsAccepted() {
        let url = URL(string: "https://pintking.app/join/aB3dE6fH/")!
        #expect(InviteLink.code(from: url) == "aB3dE6fH")
    }

    @Test(arguments: [
        "https://example.com/join/aB3dE6fH",        // someone else's domain
        "http://pintking.app/join/aB3dE6fH",        // not https
        "pintking://join/aB3dE6fH",                 // custom scheme, not a Universal Link
        "https://pintking.app/joined/aB3dE6fH",     // wrong path prefix
        "https://pintking.app/join",                // no code
        "https://pintking.app/join/aB3dE6fH/extra", // deeper path
        "https://pintking.app/join/aB3dE6f",        // 7 characters
        "https://pintking.app/join/aB3dE6fHi",      // 9 characters
        "https://pintking.app/join/aB3-E6fH",       // outside the alphabet
        "https://pintking.app/",                    // the marketing page
    ])
    func nonInviteURLsParseToNil(string: String) {
        let url = URL(string: string)!
        #expect(InviteLink.code(from: url) == nil)
    }

    @Test func percentEncodedNonASCIICodeIsRejected() {
        // Swift's `isLetter` is true for "é", but the server's alphabet is ASCII
        // only — so the length check alone would not be enough.
        let url = URL(string: "https://pintking.app/join/aB3dE6f%C3%A9")!
        #expect(InviteLink.code(from: url) == nil)
    }
}

// MARK: - QRCodeGenerator

/// Task 23: the QR code shown on the Invite screen. Every test scans the
/// generated image back with CoreImage's detector, so what is asserted is that a
/// scanner reads the right link — not merely that pixels were produced.
struct QRCodeGeneratorTests {

    @Test func generatedCodeScansBackToTheOriginalString() throws {
        let link = InviteLink.url(for: "aB3dE6fH").absoluteString
        let image = try #require(QRCodeGenerator.image(for: link))
        #expect(QRDecoder.decode(image) == link)
    }

    @Test func differentCodesProduceDifferentQRCodes() throws {
        let first = try #require(QRCodeGenerator.image(for: "https://pintking.app/join/AAAA1111"))
        let second = try #require(QRCodeGenerator.image(for: "https://pintking.app/join/BBBB2222"))
        #expect(QRDecoder.decode(first) != QRDecoder.decode(second))
    }

    @Test func emptyStringProducesNoImage() {
        #expect(QRCodeGenerator.image(for: "") == nil)
    }

    @Test func imageIsScaledUpFromTheModuleGrid() throws {
        // CoreImage emits one pixel per module; the generator scales before
        // rasterising so the code is crisp at display size rather than blurry.
        let image = try #require(QRCodeGenerator.image(for: "https://pintking.app/join/aB3dE6fH", scale: 10))
        #expect(image.size.width >= 200)
    }
}
