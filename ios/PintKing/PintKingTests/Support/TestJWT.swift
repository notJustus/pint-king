//
//  TestJWT.swift
//  PintKingTests
//
//  Mints JWT-shaped strings for the proactive-refresh tests. Only the payload's
//  `exp` claim matters — the client never verifies a signature (the server is
//  the authority on validity), so the signature segment is filler.
//

import Foundation

enum TestJWT {

    /// A token whose `exp` is `interval` seconds from now. `label` lands in the
    /// payload so two tokens minted in the same test are textually different and
    /// a test can tell which one was sent.
    static func token(expiringIn interval: TimeInterval, label: String = "test") -> String {
        let header = base64URL(Data(#"{"alg":"HS256","typ":"JWT"}"#.utf8))
        let exp = Int(Date().addingTimeInterval(interval).timeIntervalSince1970)
        let payload = base64URL(Data(#"{"sub":"\#(label)","exp":\#(exp)}"#.utf8))
        return "\(header).\(payload).signature"
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
