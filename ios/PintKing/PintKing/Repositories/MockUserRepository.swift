//
//  MockUserRepository.swift
//  PintKing
//
//  In-memory profile store. Holds a mutable copy of the current user so name /
//  avatar edits persist for the session (and are observable by the Profile
//  screens). Avatar upload fabricates a plausible new key rather than storing
//  the bytes — the mock only needs a distinct `avatarUrl` to prove the change.
//

import Foundation

@MainActor
@Observable
final class MockUserRepository: UserRepositoryProtocol {
    private(set) var user: User

    init(user: User = MockData.currentUser) {
        self.user = user
    }

    func getProfile() async throws -> User {
        user
    }

    @discardableResult
    func updateDisplayName(_ name: String) async throws -> User {
        user = User(
            id: user.id, appleId: user.appleId, displayName: name,
            avatarUrl: user.avatarUrl, activeGroupId: user.activeGroupId
        )
        return user
    }

    @discardableResult
    func uploadAvatar(_ imageData: Data) async throws -> User {
        user = User(
            id: user.id, appleId: user.appleId, displayName: user.displayName,
            avatarUrl: "avatars/\(user.id)/\(UUID()).jpg",
            activeGroupId: user.activeGroupId
        )
        return user
    }
}
