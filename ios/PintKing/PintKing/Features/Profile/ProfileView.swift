//
//  ProfileView.swift
//  PintKing
//
//  The Profile tab root (Task 15). A thin renderer over ProfileViewModel: a user
//  card (initials avatar, display name, total pint count) above navigation rows
//  to the profile sub-screens. The destinations (Edit Profile, My Pints, My
//  Groups, Settings) arrive in Tasks 16–19, so the rows call inert closures for
//  now — the same "wire the destination later" convention as the group switcher's
//  Create/Join buttons (Task 8).
//
//  Avatars are initials placeholders until the networking layer can load remote
//  images (Task 26), matching the leaderboard and history screens.
//

import SwiftUI

struct ProfileView: View {
    @State private var model: ProfileViewModel

    /// Sub-screen navigation hooks, injected by the parent. Inert until Tasks
    /// 16–19 supply real destinations.
    private let onEditProfile: () -> Void
    private let onMyPints: () -> Void
    private let onMyGroups: () -> Void
    private let onSettings: () -> Void

    init(
        userRepository: any UserRepositoryProtocol,
        pintRepository: any PintRepositoryProtocol,
        onEditProfile: @escaping () -> Void = {},
        onMyPints: @escaping () -> Void = {},
        onMyGroups: @escaping () -> Void = {},
        onSettings: @escaping () -> Void = {}
    ) {
        _model = State(initialValue: ProfileViewModel(
            userRepository: userRepository,
            pintRepository: pintRepository
        ))
        self.onEditProfile = onEditProfile
        self.onMyPints = onMyPints
        self.onMyGroups = onMyGroups
        self.onSettings = onSettings
    }

    var body: some View {
        List {
            Section {
                userCard
                    .redacted(reason: model.isLoading && model.user == nil ? .placeholder : [])
            }

            Section {
                row("Edit Profile", systemImage: "pencil", action: onEditProfile)
                row("My Pints", systemImage: "mug", action: onMyPints)
                row("My Groups", systemImage: "person.3", action: onMyGroups)
                row("Settings", systemImage: "gearshape", action: onSettings)
            }
        }
        .navigationTitle("Profile")
        .task { await model.load() }
        .refreshable { await model.refresh() }
    }

    /// Avatar + name + total pint count.
    private var userCard: some View {
        HStack(spacing: 16) {
            AvatarCircle(name: model.displayName)
                .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 4) {
                Text(model.displayName)
                    .font(.title2.weight(.semibold))
                Text("^[\(model.totalPintCount) pint](inflect: true) logged")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    /// A tappable navigation-style row with a leading icon and a chevron.
    private func row(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .foregroundStyle(.primary)
    }
}

/// Circular initials placeholder (real avatars arrive with networking, Task 26).
/// Mirrors the leaderboard's private AvatarCircle; kept local to the Profile
/// feature rather than shared until a second caller genuinely needs it.
private struct AvatarCircle: View {
    let name: String

    var body: some View {
        ZStack {
            Circle().fill(.tint.opacity(0.2))
            Text(InitialsGenerator.initials(from: name))
                .font(.title3.weight(.semibold))
                .foregroundStyle(.tint)
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView(
            userRepository: MockUserRepository(),
            pintRepository: MockPintRepository()
        )
    }
}
