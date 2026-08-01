//
//  InviteLink.swift
//  PintKing
//
//  The one place that knows what an invite link looks like
//  (`https://pintking.app/join/{code}`, l3-ios-app.md §"Deep-Linking").
//
//  Two screens sit on opposite ends of this format: the Invite screen builds a
//  link from a code (Task 23), and the deep-link handler parses a code back out
//  of a tapped Universal Link (Task 28). Keeping both sides in one namespace is
//  what stops them from drifting — the round-trip is a property of this type, not
//  a convention two features happen to share.
//
//  A pure, stateless `enum` namespace, like InitialsGenerator and ImageValidator.
//

import Foundation

enum InviteLink {
    /// The Universal Link domain (see deployment.md — `apple-app-site-association`
    /// is served from here).
    static let host = "pintking.app"

    /// The path segment that marks a URL as an invite.
    static let pathPrefix = "join"

    /// Invite codes are exactly 8 characters (Property 10).
    static let codeLength = 8

    /// The shareable link for an invite code.
    ///
    /// Non-optional by design: `URLComponents` percent-encodes whatever it is
    /// given, so building the URL cannot fail for any string — and invite codes
    /// are 8 alphanumerics anyway (Property 10).
    static func url(for inviteCode: String) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = "/\(pathPrefix)/\(inviteCode)"
        return components.url!
    }

    /// The invite code carried by a tapped Universal Link, or nil if the URL is
    /// not one of ours. The exact inverse of `url(for:)`.
    ///
    /// Everything about the URL is checked here rather than by the caller, so an
    /// unrecognised link is a single `nil` at the parse boundary — the deep-link
    /// router has no shape rules of its own to get wrong. Scheme and host are
    /// compared case-insensitively (they are case-insensitive by RFC 3986); the
    /// **code is not**, because the server's alphabet is mixed-case and its
    /// lookup is exact.
    static func code(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "https",
              components.host?.lowercased() == host
        else { return nil }

        // Split rather than use `pathComponents` so "/join/CODE" and
        // "/join/CODE/" are the same link; a trailing slash is not a typo worth
        // rejecting. Query items (utm tags on a shared link) are ignored for free
        // — they are not part of the path.
        let segments = components.path.split(separator: "/", omittingEmptySubsequences: true)
        guard segments.count == 2, segments[0] == pathPrefix else { return nil }

        let code = String(segments[1])
        guard isValidCode(code) else { return nil }
        return code
    }

    /// Whether a string has the shape of an invite code: exactly 8 characters
    /// from the server's alphabet (Property 10).
    static func isValidCode(_ code: String) -> Bool {
        code.count == codeLength && code.allSatisfy(isCodeCharacter)
    }

    /// A character the server can put in an invite code: `a-z`, `A-Z`, `0-9`.
    ///
    /// The ASCII check matters — Swift's `isLetter`/`isNumber` are true for "é"
    /// and "٣", which the server's alphabet has no room for.
    static func isCodeCharacter(_ character: Character) -> Bool {
        character.isASCII && (character.isLetter || character.isNumber)
    }
}
