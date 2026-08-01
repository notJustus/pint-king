//
//  MultipartFormData.swift
//  PintKing
//
//  Builds `multipart/form-data` bodies for the two upload endpoints
//  (POST /pints, POST /users/me/avatar). Spring reads both the file and the
//  metadata as `@RequestParam`s, so text fields and file parts go into the same
//  body — the only difference is that a file part carries `filename` and its own
//  Content-Type.
//

import Foundation

struct MultipartFormData: Sendable {

    let boundary: String
    private var parts: [Part] = []

    private struct Part: Sendable {
        let name: String
        let filename: String?
        let mimeType: String?
        let data: Data
    }

    /// The boundary is injectable so tests get a stable, predictable body.
    init(boundary: String = "PintKing-\(UUID().uuidString)") {
        self.boundary = boundary
    }

    var contentType: String {
        "multipart/form-data; boundary=\(boundary)"
    }

    /// A plain text field. Skipped when nil, so optional metadata (note, drink
    /// type, coordinates) is simply absent rather than sent as "nil".
    mutating func addField(name: String, value: String?) {
        guard let value, let data = value.data(using: .utf8) else { return }
        parts.append(Part(name: name, filename: nil, mimeType: nil, data: data))
    }

    mutating func addFile(name: String, filename: String, mimeType: String, data: Data) {
        parts.append(Part(name: name, filename: filename, mimeType: mimeType, data: data))
    }

    func encoded() -> Data {
        var body = Data()
        for part in parts {
            body.append("--\(boundary)\r\n")
            var disposition = "Content-Disposition: form-data; name=\"\(part.name)\""
            if let filename = part.filename {
                disposition += "; filename=\"\(filename)\""
            }
            body.append(disposition + "\r\n")
            if let mimeType = part.mimeType {
                body.append("Content-Type: \(mimeType)\r\n")
            }
            body.append("\r\n")
            body.append(part.data)
            body.append("\r\n")
        }
        body.append("--\(boundary)--\r\n")
        return body
    }
}

private extension Data {
    /// Multipart framing is ASCII, so a UTF-8 encode can never fail here.
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }
}
