//
//  JSONCoding.swift
//  PintKing
//
//  Shared JSON coders configured to match the API's wire contract:
//  camelCase keys (Kotlin/Jackson default) and ISO 8601 UTC timestamps
//  (ADR-0013). Every layer that talks to the API encodes/decodes through
//  these so the format is defined in exactly one place.
//

import Foundation

enum JSONCoding {

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}
