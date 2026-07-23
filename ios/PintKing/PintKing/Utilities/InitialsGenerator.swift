//
//  InitialsGenerator.swift
//  PintKing
//
//  Turns a display name into a 1–2 character placeholder shown when a user has
//  no avatar (leaderboard rows, map pins — requirements §1.7, §7.5). Pure and
//  synchronous. Satisfies design Property 7: the result contains the first
//  character of the first word and the first character of the last word (or
//  just the first for a single word), and is never empty.
//

import Foundation

enum InitialsGenerator {

    /// Fallback when the name yields no usable characters (empty or
    /// whitespace-only), so callers always have something to render.
    private static let placeholder = "?"

    /// Builds uppercased initials from a display name. Splits on whitespace,
    /// takes the first grapheme of the first and last words. Returns
    /// `placeholder` if the name has no non-whitespace content.
    static func initials(from displayName: String) -> String {
        let words = displayName.split(whereSeparator: \.isWhitespace)
        guard let first = words.first?.first else { return placeholder }

        // `.first` is a `Character`, i.e. a whole grapheme cluster, so multi-
        // scalar glyphs (flag emoji, combining accents) stay intact.
        var initials = String(first)
        if let last = words.last?.first, words.count > 1 {
            initials.append(last)
        }
        return initials.uppercased()
    }
}
