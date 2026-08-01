//
//  MultipartFormDataTests.swift
//  PintKingTests
//
//  Task 26: multipart bodies are framed by hand (URLSession has no builder), and
//  the framing is unforgiving — one missing CRLF and Spring rejects the whole
//  upload. These tests assert the exact bytes.
//

import Foundation
import Testing
@testable import PintKing

struct MultipartFormDataTests {

    private func string(_ form: MultipartFormData) -> String {
        String(decoding: form.encoded(), as: UTF8.self)
    }

    @Test func contentTypeCarriesTheBoundary() {
        let form = MultipartFormData(boundary: "abc123")
        #expect(form.contentType == "multipart/form-data; boundary=abc123")
    }

    @Test func aTextFieldIsFramedWithItsName() {
        var form = MultipartFormData(boundary: "B")
        form.addField(name: "note", value: "Lovely stout")

        #expect(string(form) == """
        --B\r
        Content-Disposition: form-data; name="note"\r
        \r
        Lovely stout\r
        --B--\r\n
        """)
    }

    @Test func nilFieldsAreOmittedEntirely() {
        // Optional pint metadata (note, drink type, coordinates) must be absent
        // rather than present-and-empty, which the API would read as a value.
        var form = MultipartFormData(boundary: "B")
        form.addField(name: "note", value: nil)
        form.addField(name: "drinkType", value: "stout")

        let body = string(form)
        #expect(body.contains("note") == false)
        #expect(body.contains(#"name="drinkType""#))
    }

    @Test func aFilePartCarriesFilenameAndContentType() {
        var form = MultipartFormData(boundary: "B")
        form.addFile(name: "photo", filename: "pint.jpg", mimeType: "image/jpeg", data: Data([0x01, 0x02]))

        let body = string(form)
        #expect(body.contains(#"Content-Disposition: form-data; name="photo"; filename="pint.jpg""#))
        #expect(body.contains("Content-Type: image/jpeg"))
    }

    @Test func binaryDataSurvivesUnaltered() {
        // The photo is JPEG bytes, not text — they must be appended raw.
        let photo = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10])
        var form = MultipartFormData(boundary: "B")
        form.addFile(name: "photo", filename: "p.jpg", mimeType: "image/jpeg", data: photo)

        let encoded = form.encoded()
        #expect(encoded.range(of: photo) != nil)
    }

    @Test func multiplePartsAreSeparatedAndClosedOnce() {
        var form = MultipartFormData(boundary: "B")
        form.addField(name: "note", value: "a")
        form.addField(name: "drinkType", value: "ale")
        form.addFile(name: "photo", filename: "p.jpg", mimeType: "image/jpeg", data: Data([0x01]))

        let body = string(form)
        #expect(body.components(separatedBy: "--B\r\n").count == 4)   // 3 parts → 3 delimiters
        #expect(body.hasSuffix("--B--\r\n"))
    }

    @Test func anEmptyFormIsJustTheClosingBoundary() {
        #expect(string(MultipartFormData(boundary: "B")) == "--B--\r\n")
    }

    @Test func theDefaultBoundaryIsUniquePerForm() {
        #expect(MultipartFormData().boundary != MultipartFormData().boundary)
    }
}
