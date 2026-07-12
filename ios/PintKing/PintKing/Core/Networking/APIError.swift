//
//  APIError.swift
//  PintKing
//
//  Typed errors surfaced by the networking layer. `from(statusCode:)` maps an
//  HTTP response status onto a case (or nil for 2xx success), mirroring the
//  API's response conventions (l3-api.md §2) and client error-handling table
//  (l3-ios-app.md §7). The NetworkClient (Task 26) will use this mapping.
//

import Foundation

enum APIError: Error, Equatable, Sendable {
    case unauthorized       // 401
    case forbidden          // 403
    case notFound           // 404
    case conflict           // 409
    case validationFailed   // 400, 422
    case serverError        // 500 and any other non-success status
    case networkUnavailable // transport failure (no HTTP response)

    /// Maps an HTTP status code to an `APIError`, or `nil` when the status is
    /// a success (2xx). 400 and 422 both collapse to `.validationFailed`
    /// (both carry field-level validation errors — l3-ios-app.md §7). Any
    /// unrecognised non-2xx status is treated as `.serverError`.
    static func from(statusCode: Int) -> APIError? {
        switch statusCode {
        case 200..<300: return nil
        case 400, 422: return .validationFailed
        case 401: return .unauthorized
        case 403: return .forbidden
        case 404: return .notFound
        case 409: return .conflict
        default: return .serverError
        }
    }
}
