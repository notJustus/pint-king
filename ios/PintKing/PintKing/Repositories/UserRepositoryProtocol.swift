//
//  UserRepositoryProtocol.swift
//  PintKing
//
//  The signed-in user's own profile: read it, rename, change avatar. Mirrors
//  GET/PATCH /users/me and POST /users/me/avatar (l3-api.md §1, Users).
//

import Foundation

@MainActor
protocol UserRepositoryProtocol: AnyObject {
    /// Fetch the current user's profile.
    func getProfile() async throws -> User

    /// Change the display name (1–30 chars, validated by the caller/API).
    /// Returns the updated profile.
    @discardableResult
    func updateDisplayName(_ name: String) async throws -> User

    /// Upload a new avatar (already validated/converted to JPEG client-side).
    /// Returns the updated profile with its new `avatarUrl`.
    @discardableResult
    func uploadAvatar(_ imageData: Data) async throws -> User
}
