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
