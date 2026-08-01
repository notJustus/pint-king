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
}
